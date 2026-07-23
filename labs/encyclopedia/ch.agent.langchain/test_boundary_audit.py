import pytest

from boundary_audit import EffectiveRequest, assert_parity, authorize_before_chain, preserve_error


def test_hidden_framework_default_is_detected() -> None:
    direct = EffectiveRequest("fixture", 0.0, 2.0)
    wrapped = EffectiveRequest("fixture", 0.7, 2.0)
    with pytest.raises(AssertionError, match="effective request changed"):
        assert_parity(direct, wrapped)


def test_exception_category_survives_adapter_context() -> None:
    original = TimeoutError("provider timeout")
    assert preserve_error(original) is original
    assert isinstance(original, TimeoutError)


def test_authorization_is_not_hidden_inside_chain_syntax() -> None:
    calls: list[str] = []
    with pytest.raises(PermissionError, match="before chain"):
        authorize_before_chain(False, calls)
    assert calls == []
    authorize_before_chain(True, calls)
    assert calls == ["invoked"]
