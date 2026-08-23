#!/usr/bin/env python3
"""Build reproducible aggregate tables from the curated job-posting CSV."""

from __future__ import annotations

import csv
import json
import re
from collections import Counter, defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INPUT = ROOT / "raw" / "job-postings.csv"
OUTPUT = ROOT / "skill-frequency.csv"
SUMMARY = ROOT / "raw" / "analysis-summary.json"

CLUSTERS = ["Java后端", "Java+Vue全栈", "Vue3/uni-app前端", "Python/AI应用"]


def normalize_skill(value: str) -> set[str]:
    """Map one explicit platform tag to zero or more stable technical skills."""
    raw = value.strip()
    low = raw.lower().replace("_", " ")
    found: set[str] = set()

    patterns = [
        ("Spring Boot", [r"spring\s*boot", r"springboot"]),
        ("Spring Cloud", [r"spring\s*cloud", r"springcloud"]),
        ("Spring MVC", [r"spring\s*mvc", r"springmvc"]),
        ("Spring", [r"^spring$"]),
        ("MyBatis", [r"mybatis", r"mybaits"]),
        ("Java", [r"^java$", r"java开发", r"java应用"]),
        ("JavaScript", [r"javascript", r"^js$"]),
        ("TypeScript", [r"typescript", r"^ts$"]),
        ("Vue", [r"^vue(?:\.js|\d)?$", r"\bvue\b"]),
        ("React", [r"react"]),
        ("Angular", [r"angular"]),
        ("HTML5", [r"html5?", r"html"]),
        ("CSS", [r"css"]),
        ("uni-app", [r"uni-?app"]),
        ("ECharts", [r"echarts"]),
        ("Three.js", [r"three\.js"]),
        ("MySQL", [r"mysql"]),
        ("PostgreSQL", [r"postgresql", r"postgres"]),
        ("Oracle", [r"oracle"]),
        ("SQL Server", [r"sql\s*server", r"sqlserver", r"mssql"]),
        ("SQL", [r"^sql$", r"sql优化"]),
        ("Redis", [r"redis"]),
        ("MongoDB", [r"mongodb"]),
        ("Kafka", [r"kafka"]),
        ("RabbitMQ", [r"rabbitmq"]),
        ("RocketMQ", [r"rocketmq"]),
        ("Python", [r"python"]),
        ("PyTorch", [r"pytorch"]),
        ("TensorFlow", [r"tensorflow"]),
        ("Caffe", [r"caffe"]),
        ("C/C++", [r"c\+\+", r"c/c\+\+", r"^c语言$"]),
        ("Linux", [r"linux"]),
        ("Git", [r"^git$"]),
        ("Maven", [r"maven"]),
        ("Docker", [r"docker"]),
        ("Kubernetes", [r"kubernetes", r"^k8s$"]),
        ("RAG", [r"\brag\b", r"rag技术"]),
        ("LLM/大模型", [r"大模型", r"\bllm\b", r"gpt"]),
        ("AI Agent/智能体", [r"智能体", r"ai\s*agent"]),
        ("NLP", [r"自然语言处理", r"\bnlp\b", r"bert", r"roberta"]),
        ("Machine Learning", [r"机器学习"]),
        ("Deep Learning", [r"深度学习"]),
        ("Computer Vision", [r"计算机视觉", r"机器视觉", r"图像算法", r"视觉算法", r"3d视觉"]),
    ]
    for name, regexes in patterns:
        if any(re.search(pattern, low, flags=re.IGNORECASE) for pattern in regexes):
            found.add(name)
    return found


def percentile(values: list[float], fraction: float) -> float | None:
    if not values:
        return None
    ordered = sorted(values)
    position = (len(ordered) - 1) * fraction
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    weight = position - lower
    return ordered[lower] * (1 - weight) + ordered[upper] * weight


def main() -> None:
    with INPUT.open(encoding="utf-8-sig", newline="") as handle:
        rows = list(csv.DictReader(handle))

    total = len(rows)
    overall = Counter()
    by_cluster: dict[str, Counter[str]] = {cluster: Counter() for cluster in CLUSTERS}
    for row in rows:
        row_skills: set[str] = set()
        for tag in filter(None, row["skills_raw"].split("|")):
            row_skills.update(normalize_skill(tag))
        for skill in row_skills:
            overall[skill] += 1
            by_cluster[row["role_cluster"]][skill] += 1

    fields = [
        "skill",
        "postings_count",
        "postings_share_pct",
        "java_backend_count",
        "java_vue_fullstack_count",
        "vue_uniapp_frontend_count",
        "python_ai_app_count",
        "evidence_basis",
    ]
    with OUTPUT.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        for skill, count in sorted(overall.items(), key=lambda item: (-item[1], item[0].lower())):
            writer.writerow(
                {
                    "skill": skill,
                    "postings_count": count,
                    "postings_share_pct": f"{count / total * 100:.1f}",
                    "java_backend_count": by_cluster["Java后端"][skill],
                    "java_vue_fullstack_count": by_cluster["Java+Vue全栈"][skill],
                    "vue_uniapp_frontend_count": by_cluster["Vue3/uni-app前端"][skill],
                    "python_ai_app_count": by_cluster["Python/AI应用"][skill],
                    "evidence_basis": "explicit platform skill tags only",
                }
            )

    cluster_counts = Counter(row["role_cluster"] for row in rows)
    education = Counter(row["education"] or "missing" for row in rows)
    experience = Counter(row["experience"] or "missing" for row in rows)
    industries = Counter(row["industry"] or "missing" for row in rows)
    salary: dict[str, dict[str, object]] = {}
    for cluster in CLUSTERS:
        cluster_rows = [row for row in rows if row["role_cluster"] == cluster]
        monthly = [
            row
            for row in cluster_rows
            if row["salary_period"].startswith("month")
            and row["salary_min_k"]
            and row["salary_max_k"]
        ]
        midpoint = [(float(row["salary_min_k"]) + float(row["salary_max_k"])) / 2 for row in monthly]
        salary[cluster] = {
            "cluster_rows": len(cluster_rows),
            "parseable_monthly_rows": len(monthly),
            "min_k_range": [
                min((float(row["salary_min_k"]) for row in monthly), default=None),
                max((float(row["salary_min_k"]) for row in monthly), default=None),
            ],
            "max_k_range": [
                min((float(row["salary_max_k"]) for row in monthly), default=None),
                max((float(row["salary_max_k"]) for row in monthly), default=None),
            ],
            "midpoint_p25_k": percentile(midpoint, 0.25),
            "midpoint_median_k": percentile(midpoint, 0.5),
            "midpoint_p75_k": percentile(midpoint, 0.75),
        }

    summary = {
        "sample_rows": total,
        "cluster_counts": dict(cluster_counts),
        "education_counts": dict(education.most_common()),
        "experience_counts": dict(experience.most_common()),
        "industry_counts": dict(industries.most_common()),
        "salary_by_cluster": salary,
        "top_skills": overall.most_common(30),
        "method_notes": [
            "Skill counts use only explicit Zhaopin search-card tags; no title/JD inference.",
            "Salary summaries include only unambiguously parsed monthly CNY ranges.",
            "This is a stratified convenience sample, not a market-share estimate.",
        ],
    }
    SUMMARY.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()

