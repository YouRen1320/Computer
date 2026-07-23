"""Strictly typed, rebuildable status counts."""

type Status = str
type CountsByStatus = dict[Status, int]


def count_statuses(statuses: list[Status]) -> CountsByStatus:
    result: CountsByStatus = {}
    for status in statuses:
        result[status] = result.get(status, 0) + 1
    return result


def technician_label(technician_id: int | None) -> str:
    if technician_id is None:
        return "未指派"
    return f"技师-{technician_id}"
