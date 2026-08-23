from datetime import datetime


def parse_instant(raw: str) -> datetime:
    # TODO: 要求 offset-aware，并统一返回 UTC。
    return datetime.fromisoformat(raw)
