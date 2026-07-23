"""Private solution with explicit ownership of the nested tags list."""


def with_tag(order, tag):
    result = dict(order)
    result["tags"] = list(order.get("tags", []))
    result["tags"].append(tag)
    return result
