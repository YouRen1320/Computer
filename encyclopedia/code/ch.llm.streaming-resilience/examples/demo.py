from dataclasses import dataclass


@dataclass
class StreamState:
    text: str = ""
    status: str = "pending"
    request_id: str | None = None


def reduce_event(state: StreamState, event: dict) -> StreamState:
    match event["type"]:
        case "response.created":
            state.status, state.request_id = "streaming", event["request_id"]
        case "response.output_text.delta":
            state.text += event["delta"]
        case "response.completed":
            state.status = "completed"
        case "error":
            state.status = "failed"
        case _:
            pass
    return state


state = StreamState()
for item in [
    {"type": "response.created", "request_id": "req_local"},
    {"type": "response.output_text.delta", "delta": "pump "},
    {"type": "response.output_text.delta", "delta": "offline"},
    {"type": "response.completed"},
]:
    reduce_event(state, item)
assert state == StreamState("pump offline", "completed", "req_local")
print(state)
