"""Editable stream consumer starter; no provider or network is contacted."""

import asyncio


class RetryableTransport(RuntimeError):
    pass


class AuthenticationFailed(RuntimeError):
    pass


def should_retry(error: Exception, *, attempt: int, max_attempts: int) -> bool:
    del error, attempt, max_attempts
    return True


async def collect(events) -> dict[str, object]:
    text = ""
    pending_tool_calls: list[dict] = []
    try:
        async for event in events:
            if event["type"] == "delta":
                text += event["text"]
            elif event["type"] == "tool_call":
                # TODO: keep proposed side effects outside replayed stream execution.
                pending_tool_calls.append(event)
        return {"text": text, "status": "completed", "tool_calls": pending_tool_calls}
    except asyncio.CancelledError:
        return {"text": text, "status": "cancelled", "tool_calls": pending_tool_calls}
