import pytest

from solution import RateLimited, Reply, UsageError, ask


def test_solution_success_and_usage_validation() -> None:
    def fake(**kwargs):
        assert kwargs["model"] == "fixture-v1"
        return Reply("ok", "req-local", 10, 2, 3, 13)
    assert ask(fake, api_key="TEST_ONLY_CREDENTIAL", model="fixture-v1",
               prompt_version="p2", prompt="fixture")["usage"]["total"] == 13
    with pytest.raises(UsageError):
        ask(lambda **_: Reply("x", "req", 1, 2, 0, 1),
            api_key="TEST_ONLY_CREDENTIAL", model="fixture-v1",
            prompt_version="p2", prompt="fixture")


def test_solution_preserves_rate_limit() -> None:
    def limited(**_):
        raise RateLimited("429")
    with pytest.raises(RateLimited):
        ask(limited, api_key="TEST_ONLY_CREDENTIAL", model="fixture-v1",
            prompt_version="p2", prompt="fixture")
