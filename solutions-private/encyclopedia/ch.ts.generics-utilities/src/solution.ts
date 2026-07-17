// Responsibility: solve the field relationship exercise with a minimal constrained generic.
// Data source: one trusted WorkOrder and two literal keys provide the positive evidence.
// Mapping: K extends keyof T selects T[K]; Partial plus Omit derives editable WorkOrder fields.
// Side effects: applies a shallow immutable patch and writes deterministic verifier evidence.

interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
  completed: boolean;
}

function selectField<T extends object, K extends keyof T>(object: T, key: K): T[K] {
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
