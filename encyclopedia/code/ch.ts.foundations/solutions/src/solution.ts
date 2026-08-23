export function formatOwners(
  orders: readonly {
    readonly id: string;
    assignee?: string;
  }[],
  formatter: (id: string, owner: string) => string
): string[] {
  // The mapping reads caller-owned data and applies one explicit missing-value policy.
  return orders.map((order) => {
    const owner = order.assignee === undefined ? "UNASSIGNED" : order.assignee;
    return formatter(order.id, owner);
  });
}

export function transitionText(pair: readonly [string, string]): string {
  // Tuple positions are the before/after data mapping for this two-value protocol.
  return pair[0] + " -> " + pair[1];
}

export function numericId(id: number): string {
  // No runtime type guard is introduced; the private contrast depends on erasure.
  return "WO-" + id.toFixed(0);
}
