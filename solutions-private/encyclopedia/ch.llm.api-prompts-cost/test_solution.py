from dataclasses import dataclass

import pytest


class RateLimited(RuntimeError):
    pass


@dataclass(frozen=True)
class Reply:
    text: str
    request_id: str
    input_tokens: int
    output_tokens: int


def ask(client, *, api_key: str, model: str, prompt_version: str) -> dict:
    reply = client(model=model, api_key=api_key, messages=[{"role": "user", "content": "fixture"}])
    return {"text": reply.text, "model": model, "prompt_version": prompt_version,
            "request_id": reply.request_id, "usage": {"input": reply.input_tokens, "output": reply.output_tokens}}


def test_solution_success() -> None:
    def fake(**kwargs):
        assert kwargs["model"] == "fixture-v1"
        return Reply("ok", "req_local", 10, 2)
    assert ask(fake, api_key="env-fixture", model="fixture-v1", prompt_version="p2")["usage"] == {"input": 10, "output": 2}


def test_solution_preserves_rate_limit() -> None:
    def limited(**kwargs):
        raise RateLimited("429")
    with pytest.raises(RateLimited):
        ask(limited, api_key="env-fixture", model="fixture-v1", prompt_version="p2")
