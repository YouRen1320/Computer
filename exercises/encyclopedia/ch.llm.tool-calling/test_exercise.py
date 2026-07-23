SOURCE = '''
TOOLS = globals()
def run(call, user):
    # Prompt says: only admins may close orders.
    args = json.loads(call["arguments"])
    return TOOLS[call["name"]](**args)
'''


def test_explicit_allowlist() -> None:
    assert "globals()" not in SOURCE


def test_runtime_schema_validation() -> None:
    assert "model_validate_json" in SOURCE


def test_authorization_outside_prompt() -> None:
    assert "closable_order_ids" in SOURCE


def test_side_effect_has_approval_and_idempotency() -> None:
    assert "confirmation" in SOURCE and "idempotency" in SOURCE
