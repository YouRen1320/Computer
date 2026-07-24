#!/usr/bin/env python3
"""Deterministically audit cross-chapter similarity and direct HTTPS coverage.

The audit compares every chapter pair with complete Unicode character-shingle
sets.  It is intentionally a duplication/source-presence gate, not a claim
about factual correctness, source authority, or human learnability.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from functools import cmp_to_key
import json
from pathlib import Path
import re
import sys
import unicodedata
from urllib.parse import urlsplit


SCHEMA_VERSION = 1
AUDIT_ID = "p9-chapter-similarity-sources"
GENERATED_BY = "scripts/audit-chapter-similarity.py"
CHAPTER_GLOB = "book/volume-*/chapters/ch.*.md"
SHINGLE_SIZE = 7
TOP_PAIR_LIMIT = 20
JACCARD_THRESHOLD = (8, 25)  # 0.32
CONTAINMENT_THRESHOLD = (13, 20)  # 0.65

FRONT_MATTER_RE = re.compile(r"\A---\s*\n(.*?)\n---\s*(?:\n|\Z)", re.DOTALL)
CHAPTER_ID_RE = re.compile(r"^id:\s*['\"]?([^'\"\s]+)['\"]?\s*$", re.MULTILINE)
GENERATED_PREREQUISITES_RE = re.compile(
    r"<!-- BEGIN GENERATED LEARNING PREREQUISITES -->.*?"
    r"<!-- END GENERATED LEARNING PREREQUISITES -->",
    re.DOTALL,
)
HTML_COMMENT_RE = re.compile(r"<!--[\s\S]*?-->")
FENCE_OPEN_RE = re.compile(r"^\s{0,3}(`{3,}|~{3,})")
HEADING_RE = re.compile(r"^\s{0,3}#{1,6}(?:\s+|$)")
LIST_ITEM_RE = re.compile(r"^\s*(?:[-+*]|\d+[.)])\s+")
HORIZONTAL_RULE_RE = re.compile(r"^\s{0,3}(?:[-*_]\s*){3,}$")
MARKDOWN_LINK_RE = re.compile(r"\[([^\]]+)\]\([^)]*\)")
ANGLE_HTTPS_RE = re.compile(r"<https://[^>]+>")
RAW_HTTPS_RE = re.compile(r"https://[^\s<>\"']+")
INLINE_CODE_RE = re.compile(r"`+([^`]+?)`+")
URL_TRAILING_PUNCTUATION = ")]}>.,;:!?，。；：！？、"


class AuditError(RuntimeError):
    """Raised for malformed inputs or an audit that cannot be executed."""


@dataclass(frozen=True)
class Chapter:
    chapter_id: str
    path: str
    normalized_character_count: int
    shingles: frozenset[str]
    https_sources: tuple[str, ...]


@dataclass(frozen=True)
class PairResult:
    chapter_a: str
    chapter_b: str
    shingle_count_a: int
    shingle_count_b: int
    intersection_count: int
    union_count: int
    threshold_reasons: tuple[str, ...]

    @property
    def jaccard_fraction(self) -> tuple[int, int]:
        return self.intersection_count, self.union_count

    @property
    def containment_a_fraction(self) -> tuple[int, int]:
        return self.intersection_count, self.shingle_count_a

    @property
    def containment_b_fraction(self) -> tuple[int, int]:
        return self.intersection_count, self.shingle_count_b

    @property
    def max_containment_fraction(self) -> tuple[int, int]:
        a = self.containment_a_fraction
        b = self.containment_b_fraction
        return a if compare_fractions(a, b) >= 0 else b


def strip_front_matter(text: str) -> tuple[str, str]:
    match = FRONT_MATTER_RE.match(text)
    if not match:
        raise AuditError("chapter is missing YAML front matter")
    return match.group(1), text[match.end() :]


def strip_fenced_code(text: str) -> str:
    output: list[str] = []
    fence_character: str | None = None
    fence_length = 0

    for line in text.splitlines():
        if fence_character is None:
            opening = FENCE_OPEN_RE.match(line)
            if opening:
                marker = opening.group(1)
                fence_character = marker[0]
                fence_length = len(marker)
                continue
            output.append(line)
            continue

        closing = re.compile(
            rf"^\s{{0,3}}{re.escape(fence_character)}{{{fence_length},}}\s*$"
        )
        if closing.match(line):
            fence_character = None
            fence_length = 0

    return "\n".join(output)


def body_without_nonprose_regions(body: str) -> str:
    body = GENERATED_PREREQUISITES_RE.sub("\n", body)
    return strip_fenced_code(body)


def normalize_prose(body: str) -> str:
    """Return comparable prose after removing generated/template surfaces."""

    body = body_without_nonprose_regions(body)
    body = HTML_COMMENT_RE.sub(" ", body)
    prose_lines: list[str] = []
    for line in body.splitlines():
        if HEADING_RE.match(line):
            continue
        if LIST_ITEM_RE.match(line):
            continue
        if HORIZONTAL_RULE_RE.match(line):
            continue
        # Markdown tables and their separator rows are deliberately excluded.
        if "|" in line:
            continue
        prose_lines.append(line)

    prose = "\n".join(prose_lines)
    prose = MARKDOWN_LINK_RE.sub(r"\1", prose)
    prose = ANGLE_HTTPS_RE.sub(" ", prose)
    prose = RAW_HTTPS_RE.sub(" ", prose)
    prose = INLINE_CODE_RE.sub(r"\1", prose)
    prose = unicodedata.normalize("NFKC", prose).casefold()
    # Punctuation and layout should not make copied prose appear different.
    return "".join(character for character in prose if character.isalnum())


def extract_https_sources(body: str) -> tuple[str, ...]:
    """Find syntactically direct HTTPS URLs outside generated/code regions."""

    body = body_without_nonprose_regions(body)
    body = HTML_COMMENT_RE.sub(" ", body)
    sources: set[str] = set()
    for raw_url in RAW_HTTPS_RE.findall(body):
        candidate = raw_url.rstrip(URL_TRAILING_PUNCTUATION)
        try:
            parsed = urlsplit(candidate)
        except ValueError:
            continue
        if parsed.scheme == "https" and parsed.hostname:
            sources.add(candidate)
    return tuple(sorted(sources))


def build_shingles(text: str) -> frozenset[str]:
    if len(text) < SHINGLE_SIZE:
        return frozenset()
    return frozenset(
        text[index : index + SHINGLE_SIZE]
        for index in range(len(text) - SHINGLE_SIZE + 1)
    )


def load_chapters(root: Path) -> list[Chapter]:
    paths = sorted(root.glob(CHAPTER_GLOB))
    if not paths:
        raise AuditError(f"no chapters matched {CHAPTER_GLOB}")

    chapters: list[Chapter] = []
    seen_ids: set[str] = set()
    for path in paths:
        resolved = path.resolve(strict=True)
        try:
            relative = resolved.relative_to(root).as_posix()
        except ValueError as error:
            raise AuditError(f"chapter escapes repository root: {path}") from error

        text = resolved.read_text(encoding="utf-8")
        front_matter, body = strip_front_matter(text)
        id_match = CHAPTER_ID_RE.search(front_matter)
        if not id_match:
            raise AuditError(f"{relative}: front matter is missing a scalar id")
        chapter_id = id_match.group(1)
        if chapter_id in seen_ids:
            raise AuditError(f"duplicate chapter id: {chapter_id}")
        seen_ids.add(chapter_id)

        normalized = normalize_prose(body)
        chapters.append(
            Chapter(
                chapter_id=chapter_id,
                path=relative,
                normalized_character_count=len(normalized),
                shingles=build_shingles(normalized),
                https_sources=extract_https_sources(body),
            )
        )

    return sorted(chapters, key=lambda chapter: chapter.chapter_id)


def compare_fractions(left: tuple[int, int], right: tuple[int, int]) -> int:
    left_numerator, left_denominator = left
    right_numerator, right_denominator = right
    if left_denominator == 0 and right_denominator == 0:
        return 0
    if left_denominator == 0:
        return -1
    if right_denominator == 0:
        return 1
    difference = left_numerator * right_denominator - right_numerator * left_denominator
    return (difference > 0) - (difference < 0)


def reaches_threshold(value: tuple[int, int], threshold: tuple[int, int]) -> bool:
    numerator, denominator = value
    threshold_numerator, threshold_denominator = threshold
    return denominator > 0 and numerator * threshold_denominator >= denominator * threshold_numerator


def ratio_document(numerator: int, denominator: int) -> dict[str, int | float | None]:
    return {
        "numerator": numerator,
        "denominator": denominator,
        "decimal": round(numerator / denominator, 9) if denominator else None,
    }


def threshold_document(value: tuple[int, int]) -> dict[str, int | float]:
    numerator, denominator = value
    return {
        "numerator": numerator,
        "denominator": denominator,
        "decimal": numerator / denominator,
    }


def compare_pair_rank(left: PairResult, right: PairResult) -> int:
    # Highest exact containment, then highest exact Jaccard, then ids ascending.
    containment_comparison = compare_fractions(
        left.max_containment_fraction, right.max_containment_fraction
    )
    if containment_comparison:
        return -containment_comparison
    jaccard_comparison = compare_fractions(left.jaccard_fraction, right.jaccard_fraction)
    if jaccard_comparison:
        return -jaccard_comparison
    left_ids = (left.chapter_a, left.chapter_b)
    right_ids = (right.chapter_a, right.chapter_b)
    if left_ids < right_ids:
        return -1
    if left_ids > right_ids:
        return 1
    return 0


def pair_document(pair: PairResult) -> dict[str, object]:
    max_containment = pair.max_containment_fraction
    return {
        "chapter_a": pair.chapter_a,
        "chapter_b": pair.chapter_b,
        "shingle_count_a": pair.shingle_count_a,
        "shingle_count_b": pair.shingle_count_b,
        "intersection_shingle_count": pair.intersection_count,
        "union_shingle_count": pair.union_count,
        "jaccard": ratio_document(*pair.jaccard_fraction),
        "containment_a_in_b": ratio_document(*pair.containment_a_fraction),
        "containment_b_in_a": ratio_document(*pair.containment_b_fraction),
        "max_containment": ratio_document(*max_containment),
        "threshold_violation": bool(pair.threshold_reasons),
        "threshold_reasons": list(pair.threshold_reasons),
    }


def evaluate_pairs(chapters: list[Chapter]) -> list[PairResult]:
    pairs: list[PairResult] = []
    for left_index, left in enumerate(chapters):
        for right in chapters[left_index + 1 :]:
            intersection = len(left.shingles.intersection(right.shingles))
            union = len(left.shingles) + len(right.shingles) - intersection
            reasons: list[str] = []
            if reaches_threshold((intersection, union), JACCARD_THRESHOLD):
                reasons.append("jaccard")
            if reaches_threshold((intersection, len(left.shingles)), CONTAINMENT_THRESHOLD):
                reasons.append("containment_a_in_b")
            if reaches_threshold((intersection, len(right.shingles)), CONTAINMENT_THRESHOLD):
                reasons.append("containment_b_in_a")
            pairs.append(
                PairResult(
                    chapter_a=left.chapter_id,
                    chapter_b=right.chapter_id,
                    shingle_count_a=len(left.shingles),
                    shingle_count_b=len(right.shingles),
                    intersection_count=intersection,
                    union_count=union,
                    threshold_reasons=tuple(reasons),
                )
            )
    return pairs


def build_report(root_value: str | Path, *, summary_only: bool = False) -> dict[str, object]:
    root = Path(root_value).expanduser().resolve(strict=True)
    chapters = load_chapters(root)
    pairs = evaluate_pairs(chapters)
    ranked_pairs = sorted(pairs, key=cmp_to_key(compare_pair_rank))
    violations = [pair for pair in pairs if pair.threshold_reasons]
    missing_sources = [chapter.chapter_id for chapter in chapters if not chapter.https_sources]
    empty_shingle_chapters = [chapter.chapter_id for chapter in chapters if not chapter.shingles]

    failures = [
        f"chapter {chapter_id} has no direct HTTPS source outside generated prerequisites and fenced code"
        for chapter_id in missing_sources
    ]
    failures.extend(
        f"chapter {chapter_id} has fewer than {SHINGLE_SIZE} comparable Unicode characters"
        for chapter_id in empty_shingle_chapters
    )
    failures.extend(
        f"chapter pair {pair.chapter_a} <> {pair.chapter_b} reaches similarity threshold: "
        f"{', '.join(pair.threshold_reasons)}"
        for pair in violations
    )
    failures.sort()

    report: dict[str, object] = {
        "schema_version": SCHEMA_VERSION,
        "audit_id": AUDIT_ID,
        "generated_by": GENERATED_BY,
        "status": "passed" if not failures else "failed",
        "parameters": {
            "shingle_size_unicode_characters": SHINGLE_SIZE,
            "calculation": "exact-all-pairs-set-intersection-no-sampling",
            "normalization": [
                "strip-yaml-front-matter",
                "strip-generated-learning-prerequisites",
                "strip-fenced-code",
                "strip-html-comments",
                "strip-markdown-headings",
                "strip-markdown-list-items-and-tables",
                "strip-source-urls",
                "unicode-nfkc-casefold",
                "retain-unicode-alphanumeric-characters",
            ],
            "source_coverage": (
                "at-least-one-parseable-https-url-with-host-outside-front-matter-"
                "generated-prerequisites-fenced-code-and-html-comments"
            ),
            "threshold_policy": "fail-closed-when-any-exact-pair-metric-reaches-its-threshold",
            "jaccard_fail_at_or_above": threshold_document(JACCARD_THRESHOLD),
            "containment_fail_at_or_above": threshold_document(CONTAINMENT_THRESHOLD),
            "top_pair_limit": TOP_PAIR_LIMIT,
        },
        "summary": {
            "chapter_count": len(chapters),
            "evaluated_pair_count": len(pairs),
            "expected_pair_count": len(chapters) * (len(chapters) - 1) // 2,
            "unique_shingle_total": sum(len(chapter.shingles) for chapter in chapters),
            "source_covered_chapter_count": len(chapters) - len(missing_sources),
            "missing_source_chapter_count": len(missing_sources),
            "similarity_violation_count": len(violations),
            "empty_shingle_chapter_count": len(empty_shingle_chapters),
        },
        "top_pairs": [pair_document(pair) for pair in ranked_pairs[:TOP_PAIR_LIMIT]],
        "missing_source_chapter_ids": missing_sources,
        "similarity_violations": [pair_document(pair) for pair in violations],
        "failures": failures,
        "evidence_boundary": (
            "This gate proves deterministic all-pair 7-character shingle metrics and the presence "
            "of at least one syntactically valid direct HTTPS URL outside fenced/generated regions. "
            "It does not prove factual truth, source authority, citation entailment, originality, or learnability."
        ),
    }
    if summary_only:
        report["details_omitted"] = ["chapters", "pairs"]
    else:
        report["chapters"] = [
            {
                "id": chapter.chapter_id,
                "path": chapter.path,
                "normalized_character_count": chapter.normalized_character_count,
                "unique_shingle_count": len(chapter.shingles),
                "https_source_count": len(chapter.https_sources),
                "https_sources": list(chapter.https_sources),
            }
            for chapter in chapters
        ]
        report["pairs"] = [pair_document(pair) for pair in pairs]
    return report


def json_bytes(report: dict[str, object], *, pretty: bool) -> bytes:
    if pretty:
        text = json.dumps(report, ensure_ascii=False, sort_keys=True, indent=2)
    else:
        text = json.dumps(
            report,
            ensure_ascii=False,
            sort_keys=True,
            separators=(",", ":"),
        )
    return (text + "\n").encode("utf-8")


def parse_arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Audit exact Unicode shingle similarity and direct HTTPS coverage."
    )
    parser.add_argument("--root", default=Path(__file__).resolve().parent.parent)
    parser.add_argument("--output", help="Write deterministic JSON to this path")
    parser.add_argument("--pretty", action="store_true", help="Pretty-print JSON")
    parser.add_argument(
        "--summary",
        action="store_true",
        help="Omit per-chapter and all-pair arrays for embedding in the global audit",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    arguments = parse_arguments(sys.argv[1:] if argv is None else argv)
    try:
        report = build_report(arguments.root, summary_only=arguments.summary)
        payload = json_bytes(report, pretty=arguments.pretty)
        if arguments.output:
            output = Path(arguments.output).expanduser().resolve()
            output.write_bytes(payload)
            print(f"CHAPTER SIMILARITY AUDIT {str(report['status']).upper()}")
            print(f"report={output}")
        else:
            sys.stdout.buffer.write(payload)
        return 0 if report["status"] == "passed" else 1
    except (AuditError, OSError, UnicodeError) as error:
        print(f"CHAPTER SIMILARITY AUDIT FAILED: {str(error).splitlines()[0]}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
