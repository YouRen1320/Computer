"""Local-only security example for an internal derived-data endpoint."""

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


# These opaque strings are deterministic teaching fixtures, not production tokens.
TRAINING_TOKENS = {
    "training-reader": TrainingTokenRecord(
        principal=Principal(
            subject="user-1",
            tenant_id="tenant-1",
            permissions=frozenset({"suggestions:read"}),
        ),
        active=True,
    ),
    "training-denied": TrainingTokenRecord(
        principal=Principal(
            subject="user-2",
            tenant_id="tenant-1",
            permissions=frozenset(),
        ),
        active=True,
    ),
    "training-expired": TrainingTokenRecord(
        principal=Principal(
            subject="user-3",
            tenant_id="tenant-1",
            permissions=frozenset({"suggestions:read"}),
        ),
        active=False,
    ),
}

SUGGESTIONS: dict[str, dict[str, object]] = {
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

bearer = HTTPBearer(
    auto_error=False,
    scheme_name="TrainingBearer",
    description="Local opaque token used only by this executable example.",
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
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="permission denied",
            )
        return principal

    return authorize


SuggestionReader = Annotated[
    Principal,
    Depends(require_permission("suggestions:read")),
]

app = FastAPI(
    title="FactoryCare Internal Suggestion Training API",
    version="1.0.0",
)


@app.get(
    "/internal/v1/suggestions/{suggestion_id}",
    response_model=SuggestionResponse,
    operation_id="getInternalSuggestion",
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
) -> dict[str, object]:
    suggestion = SUGGESTIONS.get(suggestion_id)
    # Returning 404 for a cross-tenant identifier avoids confirming its existence.
    if suggestion is None or suggestion["tenant_id"] != principal.tenant_id:
        raise HTTPException(status_code=404, detail="suggestion not found")
    return suggestion
