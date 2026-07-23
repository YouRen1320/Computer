"""Training CRUD API with explicit repository and error boundaries."""

from typing import Annotated

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field


class OrderCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)

    id: str = Field(pattern=r"^WO-[0-9]{3}$")
    title: str = Field(min_length=1, max_length=120)
    priority: int = Field(ge=1, le=5)


class OrderPatch(BaseModel):
    model_config = ConfigDict(extra="forbid", strict=True)

    title: str | None = Field(default=None, min_length=1, max_length=120)
    priority: int | None = Field(default=None, ge=1, le=5)


class OrderResponse(BaseModel):
    id: str
    title: str
    priority: int


class DuplicateOrder(Exception):
    pass


class RepositoryUnavailable(Exception):
    pass


class MemoryRepository:
    def __init__(self) -> None:
        self._orders: dict[str, dict[str, object]] = {
            "WO-001": {
                "id": "WO-001",
                "title": "Inspect pump",
                "priority": 4,
                "internal_secret": "not-public",
            }
        }

    def list(self, min_priority: int) -> list[dict[str, object]]:
        return [
            dict(order)
            for order in self._orders.values()
            if isinstance(order["priority"], int) and order["priority"] >= min_priority
        ]

    def get(self, order_id: str) -> dict[str, object] | None:
        value = self._orders.get(order_id)
        return dict(value) if value is not None else None

    def create(self, command: OrderCreate) -> dict[str, object]:
        if command.id in self._orders:
            raise DuplicateOrder(command.id)
        value: dict[str, object] = {**command.model_dump(), "internal_secret": "not-public"}
        self._orders[command.id] = value
        return dict(value)

    def patch(self, order_id: str, command: OrderPatch) -> dict[str, object] | None:
        value = self._orders.get(order_id)
        if value is None:
            return None
        changes = command.model_dump(exclude_none=True)
        value.update(changes)
        return dict(value)

    def delete(self, order_id: str) -> bool:
        return self._orders.pop(order_id, None) is not None


repository = MemoryRepository()


def get_repository() -> MemoryRepository:
    return repository


Repository = Annotated[MemoryRepository, Depends(get_repository)]
MinimumPriority = Annotated[int, Query(ge=1, le=5)]
app = FastAPI(title="Training CRUD API")


@app.exception_handler(RequestValidationError)
async def invalid_request(request: Request, exc: RequestValidationError) -> JSONResponse:
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


@app.exception_handler(DuplicateOrder)
async def duplicate_order(request: Request, exc: DuplicateOrder) -> JSONResponse:
    del request, exc
    return JSONResponse(status_code=409, content={"code": "ORDER_ALREADY_EXISTS"})


@app.exception_handler(RepositoryUnavailable)
async def repository_unavailable(
    request: Request,
    exc: RepositoryUnavailable,
) -> JSONResponse:
    del request, exc
    return JSONResponse(status_code=503, content={"code": "DEPENDENCY_UNAVAILABLE"})


@app.exception_handler(Exception)
async def unexpected_error(request: Request, exc: Exception) -> JSONResponse:
    del request, exc
    return JSONResponse(status_code=500, content={"code": "INTERNAL_ERROR"})


@app.get("/training/work-orders/special", operation_id="getSpecialTrainingOrderLab")
def special() -> dict[str, str]:
    return {"kind": "special"}


@app.get(
    "/training/work-orders",
    response_model=list[OrderResponse],
    operation_id="listTrainingOrders",
)
def list_orders(records: Repository, min_priority: MinimumPriority = 1) -> list[dict[str, object]]:
    return records.list(min_priority)


@app.get(
    "/training/work-orders/{order_id}",
    response_model=OrderResponse,
    operation_id="getTrainingOrderLab",
)
def get_order(order_id: str, records: Repository) -> dict[str, object]:
    value = records.get(order_id)
    if value is None:
        raise HTTPException(status_code=404, detail="training order not found")
    return value


@app.post(
    "/training/work-orders",
    response_model=OrderResponse,
    status_code=status.HTTP_201_CREATED,
    operation_id="createTrainingOrderLab",
)
def create_order(command: OrderCreate, records: Repository) -> dict[str, object]:
    return records.create(command)


@app.patch(
    "/training/work-orders/{order_id}",
    response_model=OrderResponse,
    operation_id="patchTrainingOrderLab",
)
def patch_order(
    order_id: str,
    command: OrderPatch,
    records: Repository,
) -> dict[str, object]:
    value = records.patch(order_id, command)
    if value is None:
        raise HTTPException(status_code=404, detail="training order not found")
    return value


@app.delete(
    "/training/work-orders/{order_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    operation_id="deleteTrainingOrderLab",
)
def delete_order(order_id: str, records: Repository) -> Response:
    if not records.delete(order_id):
        raise HTTPException(status_code=404, detail="training order not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)
