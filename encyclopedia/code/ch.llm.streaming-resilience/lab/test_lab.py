import asyncio
from collections.abc import AsyncIterator
from dataclasses import dataclass

import pytest


class ProviderFailure(RuntimeError):
    def __init__(self, status: int, code: str):
        super().__init__(code)
        self.status, self.code = status, code


@dataclass(frozen=True)
class StreamResult:
    text: str
    status: str
    attempts: int
    fallback_used: bool = False


class ScriptedProvider:
    def __init__(self, attempts: list[list[dict] | BaseException], fallback: str = "fallback"):
        self.attempts = list(attempts)
        self.stream_calls = 0
        self.fallback_calls = 0
        self.closed = 0

    async def stream(self) -> AsyncIterator[dict]:
        self.stream_calls += 1
        script = self.attempts.pop(0)
        if isinstance(script, BaseException):
            raise script
        try:
            for event in script:
                if event.get("delay"):
                    await asyncio.sleep(event["delay"])
                yield event
        finally:
            self.closed += 1

    async def nonstream(self) -> str:
        self.fallback_calls += 1
        return "fallback"


def retryable(exc: BaseException) -> bool:
    return isinstance(exc, ProviderFailure) and (exc.status == 429 or exc.status >= 500)


async def consume(provider: ScriptedProvider, *, first_event_timeout: float = 0.02,
                  max_attempts: int = 2, allow_fallback: bool = True) -> StreamResult:
    for attempt in range(1, max_attempts + 1):
        chunks: list[str] = []
        terminal = False
        iterator = provider.stream().__aiter__()
        try:
            first = await asyncio.wait_for(anext(iterator), timeout=first_event_timeout)
            events = _prepend(first, iterator)
            async for event in events:
                kind = event["type"]
                if kind == "response.output_text.delta":
                    chunks.append(event["delta"])
                elif kind == "response.completed":
                    terminal = True
                elif kind == "error":
                    raise ProviderFailure(event["status"], event["code"])
            if terminal:
                return StreamResult("".join(chunks), "completed", attempt)
            return StreamResult("".join(chunks), "partial", attempt)
        except asyncio.CancelledError:
            await iterator.aclose()
            raise
        except (TimeoutError, ProviderFailure) as exc:
            await iterator.aclose()
            can_retry = not chunks and retryable(exc) and attempt < max_attempts
            if can_retry:
                await asyncio.sleep(0)
                continue
            if allow_fallback and not chunks and (isinstance(exc, TimeoutError) or retryable(exc)):
                return StreamResult(await provider.nonstream(), "completed", attempt, True)
            raise
    raise AssertionError("unreachable")


async def _prepend(first: dict, rest: AsyncIterator[dict]) -> AsyncIterator[dict]:
    yield first
    async for event in rest:
        yield event


@pytest.mark.asyncio
async def test_completed_requires_terminal_event() -> None:
    provider = ScriptedProvider([[{"type": "response.output_text.delta", "delta": "half"}]])
    assert await consume(provider) == StreamResult("half", "partial", 1)


@pytest.mark.asyncio
async def test_429_retries_before_any_visible_output() -> None:
    provider = ScriptedProvider([ProviderFailure(429, "rate_limit"), [
        {"type": "response.output_text.delta", "delta": "ok"}, {"type": "response.completed"}]])
    assert await consume(provider) == StreamResult("ok", "completed", 2)
    assert provider.stream_calls == 2


@pytest.mark.asyncio
async def test_first_event_timeout_uses_explicit_fallback() -> None:
    provider = ScriptedProvider([[{"type": "response.output_text.delta", "delta": "late", "delay": 0.05}]])
    result = await consume(provider, first_event_timeout=0.001)
    assert result.fallback_used and provider.fallback_calls == 1


@pytest.mark.asyncio
async def test_user_cancel_propagates_and_closes_iterator() -> None:
    provider = ScriptedProvider([[{"type": "response.output_text.delta", "delta": "late", "delay": 1}]])
    task = asyncio.create_task(consume(provider, first_event_timeout=2))
    await asyncio.sleep(0)
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
    assert provider.fallback_calls == 0
    assert task.done()


@pytest.mark.asyncio
async def test_authentication_is_not_retried_or_downgraded() -> None:
    provider = ScriptedProvider([ProviderFailure(401, "invalid_api_key")])
    with pytest.raises(ProviderFailure, match="invalid_api_key"):
        await consume(provider)
    assert provider.stream_calls == 1 and provider.fallback_calls == 0
