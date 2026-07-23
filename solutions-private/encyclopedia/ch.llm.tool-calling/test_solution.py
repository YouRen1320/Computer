from pydantic import BaseModel, ConfigDict


class Args(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    order_id: int


def dispatch(name: str, raw: str, allowed: frozenset[int], repo: dict[int, dict]) -> dict:
    if name != "get_order":
        return {"ok": False, "code": "tool_not_allowed"}
    args = Args.model_validate_json(raw)
    if args.order_id not in allowed:
        return {"ok": False, "code": "forbidden"}
    return {"ok": True, "code": "ok", "data": repo[args.order_id]}


def test_solution() -> None:
    repo = {7: {"id": 7}}
    assert dispatch("get_order", '{"order_id":7}', frozenset({7}), repo)["ok"]
    assert dispatch("get_order", '{"order_id":7}', frozenset(), repo)["code"] == "forbidden"
    assert dispatch("delete_all", '{}', frozenset({7}), repo)["code"] == "tool_not_allowed"
