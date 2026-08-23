"""Private solution with an explicit public response model."""

from fastapi import FastAPI
from pydantic import BaseModel


class OrderResponse(BaseModel):
    id: str
    title: str
    priority: int


app = FastAPI()


@app.get("/training/work-orders/{order_id}", response_model=OrderResponse)
def get_order(order_id: str) -> dict[str, object]:
    return {
        "id": order_id,
        "title": "Inspect pump",
        "priority": 4,
        "internal_secret": "must-not-leak",
    }
