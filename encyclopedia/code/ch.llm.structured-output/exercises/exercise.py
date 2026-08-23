"""Editable starter: replace permissive JSON repair with a strict versioned model."""

import json

from pydantic import BaseModel


class ClassificationV1(BaseModel):
    category: str
    priority: str


def parse(raw: str) -> dict:
    try:
        return json.loads(raw)
    except Exception:
        return {"category": "OTHER", "priority": "HIGH"}
