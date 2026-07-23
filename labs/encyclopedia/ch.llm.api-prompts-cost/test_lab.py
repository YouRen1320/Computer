from dataclasses import dataclass
from decimal import Decimal
from typing import Protocol

import pytest


class ProviderError(RuntimeError):
    def __init__(self, status: int, code: str, request_id: str):
        super().__init__(code)
        self.status, self.code, self.request_id = status, code, request_id


@dataclass(frozen=True)
class ProviderResponse:
    text: str
    model: str
    request_id: str
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int


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
    usage = {
        "input": response.input_tokens,
        "cached_input": response.cached_input_tokens,
        "output": response.output_tokens,
    }
    rate = {"input": Decimal("2"), "cached_input": Decimal("0.5"), "output": Decimal("8")}
    uncached = usage["input"] - usage["cached_input"]
    cost = (Decimal(uncached) * rate["input"] + Decimal(usage["cached_input"]) * rate["cached_input"] + Decimal(usage["output"]) * rate["output"]) / Decimal(1_000_000)
    return {"text": response.text, "model": response.model, "request_id": response.request_id,
            "prompt_version": prompt_version, "usage": usage, "estimated_usd": cost}


def test_success_records_contract_without_secret() -> None:
    fake = ScriptedClient(ProviderResponse("MECHANICAL", "fixture-model-v1", "req_local_1", 120, 20, 8))
    record = invoke(fake, api_key="test-only-secret", model="fixture-model-v1", prompt_version="classify-v3")
    assert record["usage"] == {"input": 120, "cached_input": 20, "output": 8}
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
