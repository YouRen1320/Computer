// Responsibility: repair a field accessor so its key and return value remain related to the input object.
// Data source: one trusted WorkOrder and two literal field names provide the positive runtime fixtures.
// Mapping: each valid key must map to exactly its indexed-access value type; the patch excludes id.
// Side effects: applies a shallow immutable patch and writes deterministic evidence after compilation.

export interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
  completed: boolean;
}

export function selectField<T extends object>(object: T, key: string): unknown {
  // TODO: add K extends keyof T and return T[K]; do not use any or an assertion.
  return object[key];
}

type WorkOrderPatch = Partial<Omit<WorkOrder, "id">>;

function applyPatch(current: WorkOrder, patch: WorkOrderPatch): WorkOrder {
  return { ...current, ...patch };
}

const order: WorkOrder = {
  id: "WO-31",
  title: "Inspect motor",
  priority: "high",
  completed: false
};

const id: string = selectField(order, "id");
const priority: WorkOrder["priority"] = selectField(order, "priority");
const patched = applyPatch(order, { title: "Inspect drive", priority: "low" });

console.log("id=" + id);
console.log("priority=" + priority);
console.log("patched=" + JSON.stringify(patched));
console.log("GENERICS_UTILITIES_EXERCISE_PASS");
