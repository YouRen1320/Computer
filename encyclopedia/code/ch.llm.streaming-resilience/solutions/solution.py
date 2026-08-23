import asyncio


class RetryableTransport(RuntimeError):
    pass


class AuthenticationFailed(RuntimeError):
    pass


def should_retry(error: Exception, *, attempt: int, max_attempts: int) -> bool:
    return isinstance(error, RetryableTransport) and attempt < max_attempts


async def collect(events) -> dict[str, object]:
    chunks: list[str] = []
    pending_tool_calls: list[dict] = []
    try:
        async for event in events:
            if event["type"] == "delta":
                chunks.append(event["text"])
            elif event["type"] == "tool_call":
                pending_tool_calls.append(event)
            elif event["type"] == "response.completed":
                return {"text": "".join(chunks), "status": "completed",
                        "tool_calls": pending_tool_calls}
        return {"text": "".join(chunks), "status": "partial",
                "tool_calls": pending_tool_calls}
    except asyncio.CancelledError:
        raise
