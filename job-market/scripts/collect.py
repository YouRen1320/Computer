#!/usr/bin/env python3
"""Collect a small, reproducible Nanchang job-market sample from Zhaopin.

The script intentionally stores only fields needed for personal study/job-search
analysis. It does not collect recruiter contact/profile data, and it throttles
requests to avoid burdening the public search endpoint.
"""

from __future__ import annotations

import csv
import json
import random
import re
import time
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import requests


ROOT = Path(__file__).resolve().parents[1]
RAW_DIR = ROOT / "raw"
OUT_CSV = RAW_DIR / "job-postings.csv"
SUMMARY_JSON = RAW_DIR / "collection-summary.json"

API_URL = "https://fe-api.zhaopin.com/c/i/search/positions"
CITY_CODE = "691"
CITY_NAME = "南昌"
CLIENT_ID = "63ce3555-d2f2-470a-80f4-8538cee76c41"
API_VERSION = "0.43240637"
LOCAL_TZ = timezone(timedelta(hours=8))
RETRIEVED_DT = datetime.now(LOCAL_TZ).replace(microsecond=0)
RETRIEVED_AT = RETRIEVED_DT.isoformat()
SNAPSHOT_DATE = RETRIEVED_DT.date()
RECENT_CUTOFF = datetime.combine(SNAPSHOT_DATE - timedelta(days=90), datetime.min.time())

# Enough pages to represent all target clusters without treating search counts
# as market share. The endpoint returns at most 20 cards per page in practice.
QUERY_PAGES = {
    "Java": 5,
    "Java Vue": 3,
    "全栈开发": 2,
    "Vue": 2,
    "前端开发": 3,
    "uni-app": 1,
    "小程序开发": 1,
    "Python": 4,
    "人工智能": 2,
    "大模型": 2,
    "RAG": 1,
    "AI应用": 1,
}

FIELDS = [
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


def request_page(keyword: str, page: int) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    request_id = f"{int(time.time() * 1000)}-{random.randint(100000, 999999)}"
    headers = {
        "Accept": "application/json, text/plain, */*",
        "Content-Type": "application/json;charset=UTF-8",
        "Origin": "https://www.zhaopin.com",
        "Referer": "https://www.zhaopin.com/",
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/143.0 Safari/537.36",
        "x-zp-page-code": "4019",
        "x-zp-platform": "13",
        "x-zp-business-system": "1",
    }
    params = {
        "_v": API_VERSION,
        "x-zp-page-request-id": request_id,
        "x-zp-client-id": CLIENT_ID,
    }
    payload = {
        "S_SOU_FULL_INDEX": keyword,
        "S_SOU_WORK_CITY": CITY_CODE,
        "order": 4,
        "pageIndex": page,
        "pageSize": 50,
        "anonymous": 1,
        "eventScenario": "pcSearchedSouSearch",
        "platform": 13,
        "version": "0.0.0",
    }
    response = requests.post(
        API_URL,
        params=params,
        headers=headers,
        data=json.dumps(payload, ensure_ascii=False),
        timeout=20,
    )
    response.raise_for_status()
    body = response.json()
    if body.get("code") != 200 or body.get("apiCode") != 200:
        raise RuntimeError(f"Unexpected API response for {keyword=} {page=}: {body.get('code')}")
    data = body.get("data") or {}
    if data.get("isVerification"):
        raise RuntimeError(f"Verification requested for {keyword=} {page=}; stop rather than bypass it")
    return data.get("list") or [], {
        "keyword": keyword,
        "page": page,
        "reported_count": data.get("count"),
        "returned": len(data.get("list") or []),
        "is_end_page": data.get("isEndPage"),
    }


def canonical_url(item: dict[str, Any]) -> str:
    number = str(item.get("number") or "").strip()
    if number:
        return f"https://www.zhaopin.com/jobdetail/{number}.htm"
    url = str(item.get("positionUrl") or item.get("positionURL") or "").strip()
    return url.replace("http://", "https://", 1)


def parse_salary(raw: str) -> tuple[str, str, str]:
    """Return monthly CNY thousands only when conversion is unambiguous."""
    text = (raw or "").replace(" ", "")
    if not text or "面议" in text:
        return "", "", "negotiable"
    if "/天" in text or "元/天" in text:
        return "", "", "day"
    if "/时" in text or "元/时" in text:
        return "", "", "hour"
    if "/周" in text or "元/周" in text:
        return "", "", "week"
    if "/年" in text or "年薪" in text:
        return "", "", "year"

    period = "month"
    pay_match = re.search(r"[·・](\d{2})薪", text)
    if pay_match:
        period = f"month_{pay_match.group(1)}"

    wan = re.search(r"(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)万", text)
    yuan = re.search(r"(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)元", text)
    single_wan = re.search(r"^(\d+(?:\.\d+)?)万", text)
    single_yuan = re.search(r"^(\d+(?:\.\d+)?)元", text)
    if wan:
        low, high = float(wan.group(1)) * 10, float(wan.group(2)) * 10
    elif yuan:
        low, high = float(yuan.group(1)) / 1000, float(yuan.group(2)) / 1000
    elif single_wan:
        low = high = float(single_wan.group(1)) * 10
    elif single_yuan:
        low = high = float(single_yuan.group(1)) / 1000
    else:
        return "", "", "unknown"

    def fmt(value: float) -> str:
        return f"{value:.2f}".rstrip("0").rstrip(".")

    return fmt(low), fmt(high), period


def text_blob(item: dict[str, Any]) -> str:
    skills = " ".join(str(x.get("name") or "") for x in item.get("jobSkillTags") or [])
    labels = " ".join(str(x.get("value") or "") for x in item.get("skillLabel") or [])
    return " ".join(
        [
            str(item.get("name") or ""),
            str(item.get("subJobTypeLevelName") or ""),
            skills,
            labels,
        ]
    ).lower()


def classify(item: dict[str, Any], keywords: set[str]) -> str | None:
    # Query terms are deliberately excluded from classification: a card returned
    # for "Java Vue" is not proof that the employer explicitly requested Vue.
    blob = text_blob(item)
    title = str(item.get("name") or "").lower()
    skill_values = {
        str(x.get("name") or "").strip().lower() for x in item.get("jobSkillTags") or []
    } | {
        str(x.get("value") or "").strip().lower() for x in item.get("skillLabel") or []
    }
    excluded_titles = [
        "客服",
        "讲师",
        "教师",
        "销售",
        "产品经理",
        "训练师",
        "标注",
        "运营",
        "线上兼职",
        "测试助理",
        "技术支持",
        "硬件",
        "软件实施",
        "android",
        "不限语言",
    ]
    if any(term in title for term in excluded_titles):
        return None

    ai_terms = [
        "python",
        "人工智能",
        "大模型",
        "llm",
        "rag",
        "langchain",
        "机器学习",
        "深度学习",
        "算法",
        "ai开发",
        "ai应用",
        "智能体",
        "计算机视觉",
        "视觉算法",
    ]
    ai_title_terms = [
        "python",
        "人工智能",
        "大模型",
        "llm",
        "rag",
        "机器学习",
        "深度学习",
        "算法",
        "ai",
        "智能体",
        "视觉",
    ]
    development_title_terms = ["开发", "工程师", "算法", "研发", "程序", "实习"]
    if any(term in blob for term in ai_terms) and any(term in title for term in ai_title_terms):
        if any(term in title for term in development_title_terms):
            return "Python/AI应用"

    frontend_terms = ["vue", "vue.js", "vue3", "uni-app", "uniapp", "前端", "web前端", "小程序", "javascript", "typescript", "html", "css"]
    fullstack_title = any(term in title for term in ["全栈", "前后端", "java vue", "java+vue"])
    has_vue_family = any(
        "vue" in skill or "uni-app" in skill or "uniapp" in skill for skill in skill_values
    )
    has_frontend = any(
        any(term == skill or term in skill for skill in skill_values) for term in frontend_terms
    )
    has_java_skill = any(
        skill == "java"
        or skill.startswith("java ")
        or skill.startswith("java开发")
        or "spring" in skill
        or "mybatis" in skill
        or "j2ee" in skill
        for skill in skill_values
    )
    has_java = "java" in title or has_java_skill
    # Title intent wins over the platform's sometimes broad sub-job category.
    if any(term in title for term in ["前端", "vue", "web前端", "h5", "小程序", "uni-app", "uniapp"]):
        if not fullstack_title and "java" not in title:
            return "Vue3/uni-app前端"

    if (fullstack_title and (has_java or has_vue_family)) or (
        has_java and has_frontend and any(term in title for term in development_title_terms)
    ):
        return "Java+Vue全栈"

    if has_frontend and not has_java and any(term in title for term in ["开发", "工程师", "研发"]):
        return "Vue3/uni-app前端"

    java_title = (
        "java" in title
        or (any(term in title for term in ["后端", "后台", "服务端"]) and has_java)
        or (any(term in title for term in ["软件开发", "研发工程师", "开发工程师"]) and has_java)
    )
    if has_java and java_title:
        return "Java后端"
    return None


def parse_publish_time(value: str) -> datetime | None:
    if not value:
        return None
    try:
        return datetime.strptime(value, "%Y-%m-%d %H:%M:%S")
    except ValueError:
        return None


def choose_keywords(item: dict[str, Any]) -> set[str]:
    return set(item.pop("_matched_keywords", []))


def main() -> None:
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    by_url: dict[str, dict[str, Any]] = {}
    page_log: list[dict[str, Any]] = []

    for keyword, pages in QUERY_PAGES.items():
        for page in range(1, pages + 1):
            items, meta = request_page(keyword, page)
            page_log.append(meta)
            for item in items:
                if str(item.get("workCity") or "").strip() != CITY_NAME:
                    continue
                url = canonical_url(item)
                if not url:
                    continue
                if url not in by_url:
                    item = dict(item)
                    item["_matched_keywords"] = [keyword]
                    by_url[url] = item
                else:
                    by_url[url].setdefault("_matched_keywords", []).append(keyword)
            # A modest delay makes this a personal sample, not a high-rate crawl.
            time.sleep(random.uniform(0.45, 0.75))
            if not items or meta.get("is_end_page") is True:
                break

    selected: list[dict[str, str]] = []
    rejected = Counter()
    for url, item in by_url.items():
        keywords = choose_keywords(item)
        cluster = classify(item, keywords)
        if not cluster:
            rejected["not_target_role"] += 1
            continue
        published = str(item.get("publishTime") or "").strip()
        publish_dt = parse_publish_time(published)
        # Prefer recent evidence. Retain undated cards, but label the limitation.
        if publish_dt and publish_dt < RECENT_CUTOFF:
            rejected["older_than_90_days"] += 1
            continue

        skills = [str(x.get("name") or "").strip() for x in item.get("jobSkillTags") or []]
        skills += [str(x.get("value") or "").strip() for x in item.get("skillLabel") or []]
        skills = list(dict.fromkeys(x for x in skills if x))
        salary_raw = str(item.get("salary60") or "").strip()
        salary_min, salary_max, salary_period = parse_salary(salary_raw)
        job_number = str(item.get("number") or "").strip()
        notes = [
            f"salary_raw={salary_raw or 'missing'}",
            f"matched_query={'|'.join(sorted(keywords))}",
            f"zhaopin_job_number={job_number or 'missing'}",
            "official structured search-card fields; full JD not independently opened",
        ]
        if not published:
            notes.append("publish/update date missing in source")
        selected.append(
            {
                "sample_id": "",
                "title": str(item.get("name") or "").strip(),
                "company": str(item.get("companyName") or "").strip(),
                "city": str(item.get("workCity") or "").strip(),
                "salary_min_k": salary_min,
                "salary_max_k": salary_max,
                "salary_period": salary_period,
                "experience": str(item.get("workingExp") or "").strip(),
                "education": str(item.get("education") or "").strip(),
                "industry": str(item.get("industryName") or "").strip(),
                "role_cluster": cluster,
                "skills_raw": "|".join(skills),
                "source_site": "智联招聘",
                "source_url": url,
                "published_or_updated": published,
                "retrieved_at": RETRIEVED_AT,
                "evidence_quality": "official_structured_search_listing",
                "notes": "; ".join(notes),
            }
        )

    # Stable ordering keeps diffs useful. Sample IDs identify this dated snapshot,
    # while source URLs/job numbers are the durable source identifiers.
    selected.sort(
        key=lambda x: (
            x["role_cluster"],
            x["published_or_updated"],
            x["company"],
            x["title"],
            x["source_url"],
        ),
        reverse=True,
    )
    for index, row in enumerate(selected, start=1):
        row["sample_id"] = f"NC-{SNAPSHOT_DATE:%Y%m%d}-{index:03d}"

    with OUT_CSV.open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(selected)

    cluster_counts = Counter(row["role_cluster"] for row in selected)
    quality_counts = Counter(row["evidence_quality"] for row in selected)
    dated = [row for row in selected if row["published_or_updated"]]
    recent_dated = [
        row
        for row in dated
        if (parse_publish_time(row["published_or_updated"]) or datetime.min) >= RECENT_CUTOFF
    ]
    summary = {
        "retrieved_at": RETRIEVED_AT,
        "endpoint": API_URL,
        "city_code": CITY_CODE,
        "city_name": CITY_NAME,
        "query_pages": QUERY_PAGES,
        "page_log": page_log,
        "unique_source_urls_before_relevance_filter": len(by_url),
        "selected_rows": len(selected),
        "cluster_counts": dict(sorted(cluster_counts.items())),
        "evidence_quality_counts": dict(sorted(quality_counts.items())),
        "dated_rows": len(dated),
        "dated_rows_within_90_days": len(recent_dated),
        "rejected": dict(sorted(rejected.items())),
    }
    SUMMARY_JSON.write_text(json.dumps(summary, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
