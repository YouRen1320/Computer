from __future__ import annotations

import asyncio
import json
from dataclasses import dataclass, field
from typing import Any

from langchain_core.callbacks import BaseCallbackHandler
from langchain_core.output_parsers import JsonOutputParser
from langchain_core.prompts import PromptTemplate
from langchain_core.runnables import RunnableLambda
from pydantic import BaseModel, ConfigDict


PROMPT = "Question: {question}\nContext:\n{context}"


class Answer(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)

    status: str
    answer: str
    source_ids: tuple[str, ...]


class ProviderTimeout(TimeoutError):
    pass


@dataclass(frozen=True)
class ModelRequest:
    prompt: str
    model: str
    temperature: float
    timeout_seconds: float


@dataclass
class FrozenRetriever:
    documents: dict[str, tuple[tuple[str, str], ...]]
    seen_authorizations: list[str] = field(default_factory=list)

    def retrieve(self, question: str, authorization: str) -> tuple[tuple[str, str], ...]:
        if authorization != "tenant-A:tech":
            raise PermissionError("authorization rejected before retrieval")
        self.seen_authorizations.append(authorization)
        return self.documents.get(question, ())


@dataclass
class FakeOfficialSDK:
    requests: list[ModelRequest] = field(default_factory=list)
    configs: list[dict[str, Any]] = field(default_factory=list)

    def complete(self, request: ModelRequest, config: dict[str, Any] | None = None) -> str:
        self.requests.append(request)
        self.configs.append(config or {})
        if "TIMEOUT" in request.prompt:
            raise ProviderTimeout("fixture provider timed out")
        source_ids = tuple(
            line.split(" ", 1)[1]
            for line in request.prompt.splitlines()
            if line.startswith("SOURCE ")
        )
        payload = {
            "status": "answered" if source_ids else "insufficient_evidence",
            "answer": "检查冷却回路。" if source_ids else "证据不足。",
            "source_ids": source_ids,
        }
        return json.dumps(payload, ensure_ascii=False)


class EventCallback(BaseCallbackHandler):
    def __init__(self) -> None:
        self.events: list[str] = []

    def on_chain_start(self, *args: Any, **kwargs: Any) -> None:
        self.events.append("start")

    def on_chain_end(self, *args: Any, **kwargs: Any) -> None:
        self.events.append("end")

    def on_chain_error(self, *args: Any, **kwargs: Any) -> None:
        self.events.append("error")


def context_payload(
    question: str,
    retriever: FrozenRetriever,
    authorization: str,
) -> dict[str, str]:
    documents = retriever.retrieve(question, authorization)
    context = "\n".join(f"SOURCE {source_id}\n{text}" for source_id, text in documents)
    return {"question": question, "context": context}


def direct_sdk_flow(
    question: str,
    retriever: FrozenRetriever,
    provider: FakeOfficialSDK,
    *,
    authorization: str,
) -> Answer:
    payload = context_payload(question, retriever, authorization)
    request = ModelRequest(
        prompt=PROMPT.format(**payload),
        model="fixture-model-v1",
        temperature=0.0,
        timeout_seconds=2.0,
    )
    return Answer.model_validate_json(provider.complete(request))


def langchain_flow(
    question: str,
    retriever: FrozenRetriever,
    provider: FakeOfficialSDK,
    *,
    authorization: str,
    callback: EventCallback,
) -> Answer:
    def retrieve_runnable(value: str, config: dict[str, Any]) -> dict[str, str]:
        configured_auth = config.get("configurable", {}).get("authorization")
        if configured_auth != authorization:
            raise PermissionError("authorization configuration changed")
        return context_payload(value, retriever, authorization)

    def model_runnable(prompt_value: Any, config: dict[str, Any]) -> str:
        request = ModelRequest(
            prompt=prompt_value.to_string(),
            model="fixture-model-v1",
            temperature=0.0,
            timeout_seconds=2.0,
        )
        return provider.complete(request, config)

    chain = (
        RunnableLambda(retrieve_runnable)
        | PromptTemplate.from_template(PROMPT)
        | RunnableLambda(model_runnable)
        | JsonOutputParser(pydantic_object=Answer)
        | RunnableLambda(Answer.model_validate)
    )
    return chain.invoke(
        question,
        config={
            "callbacks": [callback],
            "tags": ["parity"],
            "metadata": {"case": "golden"},
            "configurable": {"authorization": authorization},
        },
    )


class BlockingProvider:
    def __init__(self) -> None:
        self.started = asyncio.Event()
        self.cancelled = False

    def sync_unavailable(self, value: Any) -> str:
        raise RuntimeError("async path required")

    async def complete(self, value: Any) -> str:
        del value
        self.started.set()
        try:
            await asyncio.Event().wait()
        except asyncio.CancelledError:
            self.cancelled = True
            raise
        return "unreachable"


async def cancellation_probe() -> bool:
    provider = BlockingProvider()
    runnable = RunnableLambda(provider.sync_unavailable, afunc=provider.complete)
    task = asyncio.create_task(runnable.ainvoke("request"))
    await provider.started.wait()
    task.cancel()
    try:
        await task
    except asyncio.CancelledError:
        pass
    return provider.cancelled
