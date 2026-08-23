"""A small training-only FastAPI contract slice."""

from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field


class OrderCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)

    title: str = Field(min_length=1, max_length=120)
    priority: int = Field(ge=1, le=5)


class OrderResponse(BaseModel):
    id: str
    title: str
    priority: int


class TrainingRepository:
    def get(self, order_id: str) -> dict[str, object] | None:
        if order_id != "WO-001":
            return None
        return {
            "id": order_id,
            "title": "Inspect pump",
            "priority": 4,
            "internal_secret": "must-not-leak",
        }

    def create(self, command: OrderCreate) -> dict[str, object]:
        return {
            "id": "WO-002",
            **command.model_dump(),
            "internal_secret": "must-not-leak",
        }


repository = TrainingRepository()


def get_repository() -> TrainingRepository:
    return repository


Repository = Annotated[TrainingRepository, Depends(get_repository)]
app = FastAPI(title="Training Work Order API")


@app.exception_handler(RequestValidationError)
async def invalid_request(
    request: Request,
    exc: RequestValidationError,
) -> JSONResponse:
    del request
    return JSONResponse(
        status_code=422,
        content={
            "code": "REQUEST_INVALID",
            "errors": [
                {"location": list(error["loc"]), "type": error["type"]}
                for error in exc.errors()
            ],
        },
    )


@app.get("/health", operation_id="trainingHealth")
def health() -> dict[str, str]:
    return {"status": "ok"}


# Register the concrete route before the dynamic /{order_id} route.
@app.get("/training/work-orders/special", operation_id="getSpecialTrainingOrder")
def special_order() -> dict[str, str]:
    return {"kind": "special"}


@app.get(
    "/training/work-orders/{order_id}",
    response_model=OrderResponse,
    operation_id="getTrainingOrder",
)
def get_order(order_id: str, records: Repository) -> dict[str, object]:
    order = records.get(order_id)
    if order is None:
        raise HTTPException(status_code=404, detail="training order not found")
    return order


@app.post(
    "/training/work-orders",
    response_model=OrderResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createTrainingOrder",
)
def create_order(command: OrderCreate, records: Repository) -> dict[str, object]:
    return records.create(command)
