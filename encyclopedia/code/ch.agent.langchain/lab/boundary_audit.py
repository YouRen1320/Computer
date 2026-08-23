from dataclasses import dataclass


@dataclass(frozen=True)
class EffectiveRequest:
    model: str
    temperature: float
    timeout_seconds: float


def assert_parity(direct: EffectiveRequest, wrapped: EffectiveRequest) -> None:
    if direct != wrapped:
        raise AssertionError(f"effective request changed: direct={direct}, wrapped={wrapped}")


def preserve_error(error: BaseException) -> BaseException:
    """An adapter may add context, but callers still need the original category."""
    error.add_note("langchain adapter boundary")
    return error


def authorize_before_chain(authorized: bool, chain_calls: list[str]) -> None:
    if not authorized:
        raise PermissionError("denied before chain")
    chain_calls.append("invoked")
