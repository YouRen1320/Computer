// Responsibility: demonstrate that TypeScript trusts an over-promising user-defined predicate.
// Data source: a malformed fixture has an id but omits the title required by WorkOrder.
// Mapping: the faulty guard maps id presence to the entire WorkOrder contract without enough evidence.
// Side effects: throws the stable runtime marker when the bad predicate admits malformed data.

interface WorkOrder {
  id: string;
  title: string;
}

function isWorkOrder(value: unknown): value is WorkOrder {
  return typeof value === "object" && value !== null && "id" in value;
}

const payload: unknown = { id: "WO-BROKEN" };

try {
  if (isWorkOrder(payload)) {
    payload.title.toUpperCase();
  }
} catch {
  throw new Error("INVALID_GUARD_RUNTIME_FAULT");
}
