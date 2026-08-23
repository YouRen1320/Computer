"""Intentionally insecure public exercise: the bearer scheme is not wired in."""

from fastapi import FastAPI
from fastapi.security import HTTPBearer
from pydantic import BaseModel


class SuggestionResponse(BaseModel):
    id: str
    work_order_id: str
    summary: str


# Defining a scheme alone does not protect any endpoint.
bearer = HTTPBearer(
    auto_error=False,
    scheme_name="TrainingBearer",
    bearerFormat="opaque-training-token",
)

app = FastAPI(title="Incomplete Security Exercise")


@app.get(
    "/internal/v1/suggestions/{suggestion_id}",
    response_model=SuggestionResponse,
    operation_id="getInternalSuggestionExercise",
)
async def get_suggestion(suggestion_id: str) -> dict[str, object]:
    return {
        "id": suggestion_id,
        "work_order_id": "WO-001",
        "summary": "Inspect the pump seal",
        "internal_score": 0.93,
    }
