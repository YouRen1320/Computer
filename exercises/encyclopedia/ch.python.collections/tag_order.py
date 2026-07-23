"""Public exercise: the nested list is intentionally shared."""


def with_tag(order, tag):
    result = dict(order)
    result["tags"].append(tag)
    return result
