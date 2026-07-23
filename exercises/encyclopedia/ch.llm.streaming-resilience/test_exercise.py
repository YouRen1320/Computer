SOURCE = '''
async def chat(provider):
    while True:
        try:
            text = ""
            async for event in provider.stream():
                text += event.delta
                await execute_tool(event.tool_call)
            return {"text": text, "status": "completed"}
        except Exception:
            continue
'''


def test_retry_is_bounded_and_classified() -> None:
    assert "while True" not in SOURCE and "except Exception" not in SOURCE


def test_completion_uses_terminal_event() -> None:
    assert "response.completed" in SOURCE


def test_tool_side_effect_not_inside_replayed_stream() -> None:
    assert "execute_tool" not in SOURCE


def test_cancellation_is_preserved() -> None:
    assert "CancelledError" in SOURCE
