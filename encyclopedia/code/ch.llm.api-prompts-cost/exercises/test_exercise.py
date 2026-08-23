from pathlib import Path

import pytest

from exercise import RateLimited, Reply, UsageError, ask


def test_fixture_has_no_provider_key_prefix_or_module_credential() -> None:
    source = Path("exercise.py").read_text()
    provider_prefix = "".join(chr(value) for value in (115, 107, 45))
    assert provider_prefix not in source and "API_KEY =" not in source


def test_model_and_provider_usage_are_explicit() -> None:
    captured = {}

    def fake(**kwargs):
        captured.update(kwargs)
        return Reply("ok", "req-local", 10, 2, 3, 13)

    result = ask(fake, api_key="TEST_ONLY_CREDENTIAL", model="fixture-v1",
                 prompt_version="p2", prompt="你好")
    assert captured["model"] == "fixture-v1"
    assert result["usage"] == {"input": 10, "cached_input": 2, "output": 3, "total": 13}
    assert "TEST_ONLY_CREDENTIAL" not in repr(result)


@pytest.mark.parametrize("reply", [
    Reply("x", "req", -1, 0, 1, 0),
    Reply("x", "req", 1, 2, 1, 2),
    Reply("x", "req", 1, 0, 1, 99),
])
def test_invalid_provider_usage_is_a_separate_error(reply: Reply) -> None:
    with pytest.raises(UsageError):
        ask(lambda **_: reply, api_key="TEST_ONLY_CREDENTIAL", model="fixture-v1",
            prompt_version="p2", prompt="fixture")


def test_rate_limit_is_not_an_empty_completed_answer() -> None:
    def limited(**_):
        raise RateLimited("429")

    with pytest.raises(RateLimited):
        ask(limited, api_key="TEST_ONLY_CREDENTIAL", model="fixture-v1",
            prompt_version="p2", prompt="fixture")
