import json
from typing import Literal

from pydantic import BaseModel, ConfigDict


class GetOrderArgs(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)
    order_id: int


def get_order(args: GetOrderArgs, repository: dict[int, dict]) -> dict:
    return repository.get(args.order_id, {"error": "not_found"})


def dispatch(call: dict, repository: dict[int, dict]) -> dict:
    handlers = {"get_order": (GetOrderArgs, get_order)}
    if call["name"] not in handlers:
        return {"ok": False, "code": "tool_not_allowed", "call_id": call["call_id"]}
    schema, handler = handlers[call["name"]]
    args = schema.model_validate_json(call["arguments"])
    return {"ok": True, "code": "ok", "call_id": call["call_id"], "data": handler(args, repository)}


result = dispatch({"call_id": "call_local_1", "name": "get_order", "arguments": json.dumps({"order_id": 7})},
                  {7: {"id": 7, "status": "OPEN"}})
assert result == {"ok": True, "code": "ok", "call_id": "call_local_1", "data": {"id": 7, "status": "OPEN"}}
print(result)
