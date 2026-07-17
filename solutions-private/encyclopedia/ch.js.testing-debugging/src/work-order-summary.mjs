// summarizeWorkOrders validates and counts snapshots without changing any caller-owned value.
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

// loadSummary composes an injected loader and adds context while retaining the original cause.
export async function loadSummary(loadOrders) {
  try {
    return summarizeWorkOrders(await loadOrders());
  } catch (cause) {
    throw new Error("work-order summary load failed", { cause });
  }
}
