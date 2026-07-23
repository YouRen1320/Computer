SOURCE = '''
class Classification(BaseModel):
    category: str
    priority: str

def classify(raw):
    try:
        return json.loads(raw)
    except Exception:
        return {"category": "OTHER", "priority": "HIGH"}
'''


def test_schema_is_versioned() -> None:
    assert "schema_version" in SOURCE


def test_unknown_fields_forbidden() -> None:
    assert 'extra="forbid"' in SOURCE


def test_runtime_model_validation_used() -> None:
    assert "model_validate_json" in SOURCE


def test_parse_failure_not_repaired_to_high() -> None:
    assert '"priority": "HIGH"' not in SOURCE
