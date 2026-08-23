"""Editable offline starter; it contains no provider credential or network call."""

from dataclasses import dataclass


class RateLimited(RuntimeError):
    pass


class UsageError(RuntimeError):
    pass


@dataclass(frozen=True)
class Reply:
    text: str
    request_id: str
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int
    total_tokens: int


def ask(client, *, api_key: str, model: str, prompt_version: str, prompt: str) -> dict:
    del model
    try:
        reply = client(api_key=api_key, messages=[{"role": "user", "content": prompt}])
    except RateLimited:
        return {"text": "", "status": "completed"}
    # TODO: validate provider usage instead of estimating actual tokens from characters.
    return {
        "text": reply.text,
        "request_id": reply.request_id,
        "prompt_version": prompt_version,
        "usage": {"input": len(prompt), "cached_input": 0, "output": len(reply.text)},
    }
