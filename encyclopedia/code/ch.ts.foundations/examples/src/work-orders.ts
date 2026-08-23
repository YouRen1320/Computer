export function summarizeOrders(
  orders: readonly {
    readonly id: string;
    status: string;
    assignee?: string;
  }[],
  formatter: (id: string, status: string, owner: string) => string
): string[] {
  // orders is the only data source; the fallback is the explicit missing-assignee policy.
  return orders.map((order) => {
    const owner = order.assignee === undefined ? "UNASSIGNED" : order.assignee;
    return formatter(order.id, order.status, owner);
  });
}

export function describeTransition(transition: readonly [string, string]): string {
  // Tuple positions map to before and after; emitted JavaScript still receives a normal array.
  return transition[0] + " -> " + transition[1];
}

export function normalizeNumericId(id: number): string {
  // The number annotation is erased and deliberately contains no runtime input validation.
  return "WO-" + id.toFixed(0);
}
