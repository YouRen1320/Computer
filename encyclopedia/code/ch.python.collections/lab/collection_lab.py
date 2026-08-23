"""Collection transformations with explicit ordering and ownership."""


def unique_in_first_seen_order(values):
    seen = set()
    result = []
    for value in values:
        if value in seen:
            continue
        seen.add(value)
        result.append(value)
    return result


def index_statuses(orders):
    result = {}
    for order in orders:
        key = (order["tenant_id"], order["id"])
        if key in result:
            raise ValueError(f"duplicate order key: {key!r}")
        result[key] = order["status"]
    return result


def with_tag(order, tag):
    result = dict(order)
    result["tags"] = list(order.get("tags", []))
    result["tags"].append(tag)
    return result
