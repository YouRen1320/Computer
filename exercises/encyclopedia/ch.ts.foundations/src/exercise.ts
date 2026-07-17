export function formatOwner(order: {
  readonly id: string;
  assignee?: string;
}): string {
  // TODO: return UNASSIGNED when assignee is absent, otherwise return its uppercase text.
  return order.assignee.toUpperCase();
}

// Both calls are runtime guards so a non-null assertion cannot satisfy the exercise.
console.log("owner:" + formatOwner({ id: "WO-1", assignee: "Lin" }));
console.log("owner:" + formatOwner({ id: "WO-2" }));
console.log("TYPESCRIPT_FOUNDATIONS_EXERCISE_PASS");
