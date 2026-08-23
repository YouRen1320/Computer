import asyncio
from importlib.metadata import version

import pytest

from parity import (
    EventCallback,
    FakeOfficialSDK,
    FrozenRetriever,
    ProviderTimeout,
    cancellation_probe,
    direct_sdk_flow,
    langchain_flow,
)


def retriever() -> FrozenRetriever:
    return FrozenRetriever({"E42": (("manual-e42", "检查冷却回路。"),)})


def test_direct_sdk_and_langchain_have_request_and_output_parity() -> None:
    direct_provider = FakeOfficialSDK()
    chain_provider = FakeOfficialSDK()
    direct = direct_sdk_flow("E42", retriever(), direct_provider, authorization="tenant-A:tech")
    callback = EventCallback()
    wrapped = langchain_flow(
        "E42",
        retriever(),
        chain_provider,
        authorization="tenant-A:tech",
        callback=callback,
    )
    assert wrapped == direct
    assert chain_provider.requests == direct_provider.requests
    assert callback.events.count("start") >= 1
    assert callback.events.count("end") >= 1
    config = chain_provider.configs[0]
    assert "parity" in config["tags"]
    assert config["metadata"]["case"] == "golden"


def test_framework_preserves_error_class_and_authorization_boundary() -> None:
    with pytest.raises(ProviderTimeout, match="fixture provider timed out"):
        langchain_flow(
            "TIMEOUT",
            retriever(),
            FakeOfficialSDK(),
            authorization="tenant-A:tech",
            callback=EventCallback(),
        )
    with pytest.raises(PermissionError, match="rejected before retrieval"):
        direct_sdk_flow("E42", retriever(), FakeOfficialSDK(), authorization="wrong")


def test_async_cancellation_reaches_underlying_fixture() -> None:
    assert asyncio.run(cancellation_probe()) is True


def test_actual_library_surface_is_recorded() -> None:
    assert version("langchain").startswith("1.")
    assert version("langchain-core").startswith("1.")
