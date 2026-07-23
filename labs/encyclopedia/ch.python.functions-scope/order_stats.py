"""Functions with explicit inputs, returns and fresh default state."""


def is_active_status(status):
    return status not in {"CLOSED", "CANCELLED"}


def count_active(orders):
    count = 0
    for order in orders:
        if is_active_status(order["status"]):
            count += 1
    return count


def append_trace(message, trace=None):
    if trace is None:
        trace = []
    trace.append(message)
    return trace


def summarize(orders, *, include_trace=False):
    active = count_active(orders)
    result = {"total": len(orders), "active": active}
    if include_trace:
        result["trace"] = [f"read={len(orders)}", f"active={active}"]
    return result
