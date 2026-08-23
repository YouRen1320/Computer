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
    reply = client(model=model, api_key=api_key,
                   messages=[{"role": "user", "content": prompt}])
    counts = (reply.input_tokens, reply.cached_input_tokens,
              reply.output_tokens, reply.total_tokens)
    if any(isinstance(value, bool) or not isinstance(value, int) or value < 0 for value in counts):
        raise UsageError("usage counts must be non-negative integers")
    if reply.cached_input_tokens > reply.input_tokens:
        raise UsageError("cached input exceeds input")
    if reply.total_tokens != reply.input_tokens + reply.output_tokens:
        raise UsageError("provider total mismatch")
    return {
        "text": reply.text,
        "request_id": reply.request_id,
        "prompt_version": prompt_version,
        "usage": {"input": reply.input_tokens, "cached_input": reply.cached_input_tokens,
                  "output": reply.output_tokens, "total": reply.total_tokens},
    }
