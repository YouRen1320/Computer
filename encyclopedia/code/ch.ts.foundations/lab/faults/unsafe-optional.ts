function unsafeOwner(order: { readonly id: string; assignee?: string }): string {
  // Fault injection: optional assignee is consumed before a missing-value policy exists.
  return order.assignee.toUpperCase();
}

void unsafeOwner;
