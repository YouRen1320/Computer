"""Public exercise: the endpoint intentionally leaks an internal field."""

from fastapi import FastAPI


app = FastAPI()


@app.get("/training/work-orders/{order_id}")
def get_order(order_id: str) -> dict[str, object]:
    return {
        "id": order_id,
        "title": "Inspect pump",
        "priority": 4,
        "internal_secret": "leaked",
    }
