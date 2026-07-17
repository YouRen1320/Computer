export function buildLabels(
  orders: readonly {
    readonly id: string;
    status: string;
    assignee?: string;
  }[],
  formatter: (id: string, status: string, owner: string) => string
): string[] {
  // The optional field is normalized at the function boundary before formatting.
  return orders.map((order) => {
    const owner = order.assignee === undefined ? "UNASSIGNED" : order.assignee;
    return formatter(order.id, order.status, owner);
  });
}

export function normalizeNumericId(id: number): string {
  // This checked signature is intentionally erased so the runtime fixture can expose the boundary.
  return "WO-" + id.toFixed(0);
}
