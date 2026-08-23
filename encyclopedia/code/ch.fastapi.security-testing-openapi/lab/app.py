"""A local FastAPI lab with explicit auth, authorization and repository seams."""

from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict


@dataclass(frozen=True, slots=True)
class Principal:
    subject: str
    tenant_id: str
    permissions: frozenset[str]


@dataclass(frozen=True, slots=True)
class TrainingTokenRecord:
    principal: Principal
    active: bool


class SuggestionResponse(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [
                {
                    "id": "S-1",
                    "work_order_id": "WO-001",
                    "summary": "Inspect the pump seal",
                }
            ]
        }
    )

    id: str
    work_order_id: str
    summary: str


TRAINING_TOKENS = {
    "training-reader": TrainingTokenRecord(
        Principal("user-1", "tenant-1", frozenset({"suggestions:read"})),
        active=True,
    ),
    "training-denied": TrainingTokenRecord(
        Principal("user-2", "tenant-1", frozenset()),
        active=True,
    ),
    "training-expired": TrainingTokenRecord(
        Principal("user-3", "tenant-1", frozenset({"suggestions:read"})),
        active=False,
    ),
}

bearer = HTTPBearer(
    auto_error=False,
    scheme_name="TrainingBearer",
    description="Local opaque token used only by this executable lab.",
    bearerFormat="opaque-training-token",
)


def unauthenticated() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="valid bearer credentials required",
        headers={"WWW-Authenticate": "Bearer"},
    )


async def current_principal(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Security(bearer)],
) -> Principal:
    if credentials is None:
        raise unauthenticated()
    record = TRAINING_TOKENS.get(credentials.credentials)
    if record is None or not record.active:
        raise unauthenticated()
    return record.principal


def require_permission(permission: str):
    async def authorize(
        principal: Annotated[Principal, Depends(current_principal)],
    ) -> Principal:
        if permission not in principal.permissions:
            raise HTTPException(status_code=403, detail="permission denied")
        return principal

    return authorize


SuggestionReader = Annotated[
    Principal,
    Depends(require_permission("suggestions:read")),
]


class SuggestionRepository:
    def __init__(self) -> None:
        self.read_count = 0
        self._items: dict[str, dict[str, object]] = {
            "S-1": {
                "id": "S-1",
                "tenant_id": "tenant-1",
                "work_order_id": "WO-001",
                "summary": "Inspect the pump seal",
                "internal_score": 0.93,
            },
            "S-2": {
                "id": "S-2",
                "tenant_id": "tenant-2",
                "work_order_id": "WO-002",
                "summary": "Check the motor bearing",
                "internal_score": 0.88,
            },
        }

    def find(self, suggestion_id: str) -> dict[str, object] | None:
        self.read_count += 1
        item = self._items.get(suggestion_id)
        return dict(item) if item is not None else None


def create_app(repository: SuggestionRepository | None = None) -> FastAPI:
    records = repository or SuggestionRepository()
    app = FastAPI(
        title="FactoryCare Internal Suggestion Lab",
        version="1.0.0",
    )
    app.state.repository = records

    def provide_repository() -> SuggestionRepository:
        return records

    @app.get(
        "/internal/v1/suggestions/{suggestion_id}",
        response_model=SuggestionResponse,
        operation_id="getInternalSuggestionLab",
        summary="Read one derived suggestion",
        responses={
            401: {"description": "Credentials are absent or invalid"},
            403: {"description": "Principal lacks the required permission"},
            404: {"description": "Suggestion is absent or outside the tenant"},
        },
    )
    async def get_suggestion(
        suggestion_id: str,
        principal: SuggestionReader,
        repository: Annotated[SuggestionRepository, Depends(provide_repository)],
    ) -> dict[str, object]:
        suggestion = repository.find(suggestion_id)
        if suggestion is None or suggestion["tenant_id"] != principal.tenant_id:
            raise HTTPException(status_code=404, detail="suggestion not found")
        return suggestion

    return app


app = create_app()
