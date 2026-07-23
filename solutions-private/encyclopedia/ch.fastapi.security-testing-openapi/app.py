"""Private reference solution for the missing security dependency exercise."""

from dataclasses import dataclass
from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel


@dataclass(frozen=True, slots=True)
class Principal:
    subject: str
    permissions: frozenset[str]


class SuggestionResponse(BaseModel):
    id: str
    work_order_id: str
    summary: str


bearer = HTTPBearer(
    auto_error=False,
    scheme_name="TrainingBearer",
    description="Local opaque token used only by this reference solution.",
    bearerFormat="opaque-training-token",
)


async def current_principal(
    credentials: Annotated[HTTPAuthorizationCredentials | None, Security(bearer)],
) -> Principal:
    if credentials is None or credentials.credentials not in {
        "training-reader",
        "training-denied",
    }:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="valid bearer credentials required",
            headers={"WWW-Authenticate": "Bearer"},
        )

    permissions = (
        frozenset({"suggestions:read"})
        if credentials.credentials == "training-reader"
        else frozenset()
    )
    return Principal(subject="training-user", permissions=permissions)


async def suggestion_reader(
    principal: Annotated[Principal, Depends(current_principal)],
) -> Principal:
    if "suggestions:read" not in principal.permissions:
        raise HTTPException(status_code=403, detail="permission denied")
    return principal


app = FastAPI(title="Completed Security Exercise")


@app.get(
    "/internal/v1/suggestions/{suggestion_id}",
    response_model=SuggestionResponse,
    operation_id="getInternalSuggestionSolution",
)
async def get_suggestion(
    suggestion_id: str,
    principal: Annotated[Principal, Depends(suggestion_reader)],
) -> dict[str, object]:
    del principal
    return {
        "id": suggestion_id,
        "work_order_id": "WO-001",
        "summary": "Inspect the pump seal",
        "internal_score": 0.93,
    }
