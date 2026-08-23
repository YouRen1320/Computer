#!/usr/bin/env python3
"""Validate the dated job-market snapshot and print its evidence profile."""

from __future__ import annotations

import csv
import re
import sys
from collections import Counter
from datetime import datetime, timedelta
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
CSV_PATH = ROOT / "raw" / "job-postings.csv"
EXPECTED_FIELDS = [
    "sample_id",
    "title",
    "company",
    "city",
    "salary_min_k",
    "salary_max_k",
    "salary_period",
    "experience",
    "education",
    "industry",
    "role_cluster",
    "skills_raw",
    "source_site",
    "source_url",
    "published_or_updated",
    "retrieved_at",
    "evidence_quality",
    "notes",
]
EXPECTED_CLUSTERS = {"Java后端", "Java+Vue全栈", "Vue3/uni-app前端", "Python/AI应用"}


def main() -> int:
    errors: list[str] = []
    with CSV_PATH.open(encoding="utf-8-sig", newline="") as handle:
        reader = csv.DictReader(handle)
        rows = list(reader)
        if reader.fieldnames != EXPECTED_FIELDS:
            errors.append(f"header mismatch: {reader.fieldnames!r}")

    if len(rows) < 80:
        errors.append(f"sample size {len(rows)} is below 80")

    ids = [row["sample_id"] for row in rows]
    urls = [row["source_url"] for row in rows]
    if any(not value for value in ids):
        errors.append("blank sample_id")
    if len(ids) != len(set(ids)):
        errors.append("sample_id values are not unique")
    if any(not value for value in urls):
        errors.append("blank source_url")
    if len(urls) != len(set(urls)):
        errors.append("source_url values are not unique")

    triples = [(row["company"], row["title"], row["source_url"]) for row in rows]
    if len(triples) != len(set(triples)):
        errors.append("duplicate company/title/link triple")

    for line, row in enumerate(rows, start=2):
        if row["city"] != "南昌":
            errors.append(f"line {line}: city is not 南昌")
        if row["role_cluster"] not in EXPECTED_CLUSTERS:
            errors.append(f"line {line}: unknown role_cluster {row['role_cluster']!r}")
        parsed = urlparse(row["source_url"])
        if parsed.scheme != "https" or not parsed.netloc or "/jobdetail/" not in parsed.path:
            errors.append(f"line {line}: malformed/non-canonical source URL")
        try:
            retrieved = datetime.fromisoformat(row["retrieved_at"])
        except ValueError:
            errors.append(f"line {line}: invalid retrieved_at")
            retrieved = None
        if retrieved and not row["sample_id"].startswith(f"NC-{retrieved:%Y%m%d}-"):
            errors.append(f"line {line}: sample_id date does not match retrieved_at")
        if row["published_or_updated"]:
            try:
                published = datetime.strptime(row["published_or_updated"], "%Y-%m-%d %H:%M:%S")
                if retrieved:
                    retrieved_naive = retrieved.replace(tzinfo=None)
                    if published < retrieved_naive - timedelta(days=90) or published > retrieved_naive:
                        errors.append(f"line {line}: publication date is outside snapshot window")
                elif published > datetime.now():
                    errors.append(f"line {line}: publication date is outside snapshot window")
            except ValueError:
                errors.append(f"line {line}: invalid published_or_updated")
        number_match = re.search(r"zhaopin_job_number=([^;]+)", row["notes"])
        if not number_match or number_match.group(1) not in row["source_url"]:
            errors.append(f"line {line}: source URL does not match recorded official job number")
        if row["salary_min_k"] and row["salary_max_k"]:
            try:
                low, high = float(row["salary_min_k"]), float(row["salary_max_k"])
                if low > high or low < 0:
                    errors.append(f"line {line}: invalid salary interval")
            except ValueError:
                errors.append(f"line {line}: non-numeric salary interval")

    cluster_counts = Counter(row["role_cluster"] for row in rows)
    missing_clusters = EXPECTED_CLUSTERS - cluster_counts.keys()
    if missing_clusters:
        errors.append(f"missing clusters: {sorted(missing_clusters)}")

    print(f"rows={len(rows)}")
    print(f"columns={len(EXPECTED_FIELDS)}")
    print(f"unique_ids={len(set(ids))}")
    print(f"unique_urls={len(set(urls))}")
    print(f"source_distribution={dict(Counter(row['source_site'] for row in rows))}")
    print(f"evidence_quality={dict(Counter(row['evidence_quality'] for row in rows))}")
    print(f"cluster_distribution={dict(cluster_counts)}")
    print(f"dated_rows={sum(bool(row['published_or_updated']) for row in rows)}")
    print(f"monthly_salary_parseable={sum(row['salary_period'].startswith('month') and bool(row['salary_min_k']) for row in rows)}")

    if errors:
        print("VALIDATION_FAILED", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("VALIDATION_OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
