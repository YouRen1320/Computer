from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol

import pytest


class ProviderError(RuntimeError):
    def __init__(self, status: int, code: str, request_id: str):
        super().__init__(code)
        self.status, self.code, self.request_id = status, code, request_id


class ProviderUsageError(RuntimeError):
    """The provider replied, but its usage cannot be admitted to billing."""


@dataclass(frozen=True)
class ProviderResponse:
    text: str
    model: str
    request_id: str
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int
    total_tokens: int


@dataclass(frozen=True)
class Usage:
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int
    total_tokens: int

    @classmethod
    def from_response(cls, response: ProviderResponse) -> "Usage":
        values = (response.input_tokens, response.cached_input_tokens,
                  response.output_tokens, response.total_tokens)
        if any(isinstance(value, bool) or not isinstance(value, int) or value < 0 for value in values):
            raise ProviderUsageError("usage counts must be non-negative integers")
        if response.cached_input_tokens > response.input_tokens:
            raise ProviderUsageError("cached input exceeds input")
        if response.total_tokens != response.input_tokens + response.output_tokens:
            raise ProviderUsageError("provider total does not match its documented relation")
        return cls(*values)


class ModelClient(Protocol):
    def create(self, *, model: str, messages: list[dict[str, str]], api_key: str) -> ProviderResponse: ...


class ScriptedClient:
    def __init__(self, result: ProviderResponse | ProviderError):
        self.result = result
        self.last_request = None

    def create(self, *, model: str, messages: list[dict[str, str]], api_key: str) -> ProviderResponse:
        self.last_request = {"model": model, "messages": messages, "credential_present": bool(api_key)}
        if isinstance(self.result, ProviderError):
            raise self.result
        return self.result


def invoke(client: ModelClient, *, api_key: str, model: str, prompt_version: str) -> dict:
    if not api_key or not model or not prompt_version:
        raise ValueError("credential, model and prompt_version are required")
    response = client.create(
        model=model,
        api_key=api_key,
        messages=[
            {"role": "developer", "content": "Return one maintenance category."},
            {"role": "user", "content": "Pump P-7 is vibrating."},
        ],
    )
    checked = Usage.from_response(response)
    usage = {"input": checked.input_tokens, "cached_input": checked.cached_input_tokens,
             "output": checked.output_tokens, "total": checked.total_tokens}
    rate = {"input": Decimal("2"), "cached_input": Decimal("0.5"), "output": Decimal("8")}
    if set(rate) != {"input", "cached_input", "output"} or any(
        not value.is_finite() or value < 0 for value in rate.values()
    ):
        raise ValueError("invalid rate snapshot")
    uncached = usage["input"] - usage["cached_input"]
    cost = (Decimal(uncached) * rate["input"] + Decimal(usage["cached_input"]) * rate["cached_input"] + Decimal(usage["output"]) * rate["output"]) / Decimal(1_000_000)
    return {"text": response.text, "model": response.model, "request_id": response.request_id,
            "prompt_version": prompt_version, "usage": usage, "estimated_usd": cost}


def test_success_records_contract_without_secret() -> None:
    fake = ScriptedClient(ProviderResponse("MECHANICAL", "fixture-model-v1", "req_local_1", 120, 20, 8, 128))
    record = invoke(fake, api_key="test-only-secret", model="fixture-model-v1", prompt_version="classify-v3")
    assert record["usage"] == {"input": 120, "cached_input": 20, "output": 8, "total": 128}
    assert record["estimated_usd"] == Decimal("0.000274")
    assert "test-only-secret" not in repr(record)
    assert fake.last_request == {"model": "fixture-model-v1", "messages": [
        {"role": "developer", "content": "Return one maintenance category."},
        {"role": "user", "content": "Pump P-7 is vibrating."}], "credential_present": True}


@pytest.mark.parametrize("status,code", [(401, "invalid_api_key"), (429, "rate_limit")])
def test_provider_failures_are_not_empty_answers(status: int, code: str) -> None:
    fake = ScriptedClient(ProviderError(status, code, f"req_{status}"))
    with pytest.raises(ProviderError) as caught:
        invoke(fake, api_key="test", model="fixture-model-v1", prompt_version="classify-v3")
    assert caught.value.status == status
    assert caught.value.request_id == f"req_{status}"


@pytest.mark.parametrize("counts", [
    (-1, 0, 0, 0),
    (1, 2, 0, 1),
    (2, 0, -1, 1),
    (2, 0, 3, 99),
])
def test_invalid_provider_usage_is_not_billed(counts: tuple[int, int, int, int]) -> None:
    fake = ScriptedClient(ProviderResponse("x", "fixture-model-v1", "req_bad", *counts))
    with pytest.raises(ProviderUsageError):
        invoke(fake, api_key="test", model="fixture-model-v1", prompt_version="classify-v3")


def test_extreme_integer_usage_remains_exact() -> None:
    huge = 10**30
    fake = ScriptedClient(ProviderResponse("x", "fixture-model-v1", "req_huge",
                                           huge, huge // 2, huge, huge * 2))
    result = invoke(fake, api_key="test", model="fixture-model-v1", prompt_version="classify-v3")
    expected = (Decimal(huge // 2) * Decimal("2")
                + Decimal(huge // 2) * Decimal("0.5")
                + Decimal(huge) * Decimal("8")) / Decimal(1_000_000)
    assert result["estimated_usd"] == expected
