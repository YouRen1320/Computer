"""Group read-only order snapshots into rebuildable technician summaries."""


def group_orders(orders):
    grouped = {}
    for order in orders:
        technician_id = order.get("technician_id")
        if technician_id is None:
            continue

        if technician_id not in grouped:
            grouped[technician_id] = {
                "order_ids": [],
                "statuses": set(),
                "count": 0,
            }

        bucket = grouped[technician_id]
        bucket["order_ids"].append(order["id"])
        bucket["statuses"].add(order["status"])
        bucket["count"] += 1
    return grouped


def stable_view(grouped):
    result = {}
    for technician_id, bucket in grouped.items():
        result[str(technician_id)] = {
            "order_ids": list(bucket["order_ids"]),
            "statuses": sorted(bucket["statuses"]),
            "count": bucket["count"],
        }
    return result
