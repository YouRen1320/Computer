// summarizeWorkOrders is a pure language boundary: it validates snapshots, counts statuses, and never mutates input.
export function summarizeWorkOrders(workOrders) {
  if (!Array.isArray(workOrders)) {
    throw new TypeError("workOrders must be an array");
  }

  const counts = {};
  const ids = [];
  for (const workOrder of workOrders) {
    if (!workOrder || typeof workOrder.id !== "string" || workOrder.id.length === 0) {
      throw new TypeError("work order id is required");
    }
    if (typeof workOrder.status !== "string" || workOrder.status.length === 0) {
      throw new TypeError("work order status is required");
    }
    counts[workOrder.status] = (counts[workOrder.status] ?? 0) + 1;
    ids.push(workOrder.id);
  }

  return { total: workOrders.length, counts, ids };
}

// loadSummary owns the asynchronous loader boundary and preserves its original failure through Error.cause.
export async function loadSummary(loadOrders) {
  try {
    return summarizeWorkOrders(await loadOrders());
  } catch (cause) {
    throw new Error("work-order summary load failed", { cause });
  }
}
