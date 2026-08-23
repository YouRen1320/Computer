"""Public decorator exercise with lost metadata."""


def trace(function):
    def wrapper(*args, **kwargs):
        return function(*args, **kwargs)

    return wrapper


@trace
def close_order(order_id: int) -> str:
    """Close one order."""
    return f"closed:{order_id}"
