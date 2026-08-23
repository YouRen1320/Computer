from dataclasses import dataclass


@dataclass(frozen=True)
class Request:
    model: str
    temperature: float
    timeout_seconds: float


def direct_request() -> Request:
    return Request("fixture-model-v1", 0.0, 2.0)


def langchain_request() -> Request:
    return Request("fixture-model-v1", 0.0, 2.0)
