// Responsibility: solve the public guard and exhaustiveness obligations without unsafe escapes.
// Data source: inline unknown fixtures represent API payloads; cancelled is a trusted internal state.
// Mapping: validated own fields become WorkOrder and the status tag selects exactly one output label.
// Side effects: writes deterministic evidence; the impossible fallback throws for unchecked callers only.

interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
}

type LoadState =
  | { status: "idle" }
  | { status: "ready"; data: WorkOrder }
  | { status: "failed"; message: string }
  | { status: "cancelled"; reason: string };

function isRecord(value: unknown): value is Record<PropertyKey, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function isWorkOrder(value: unknown): value is WorkOrder {
  return (
    isRecord(value) &&
    Object.hasOwn(value, "id") &&
    Object.hasOwn(value, "title") &&
    Object.hasOwn(value, "priority") &&
    typeof value.id === "string" &&
    value.id.length > 0 &&
    typeof value.title === "string" &&
    (value.priority === "low" || value.priority === "high")
  );
}

function renderState(state: LoadState): string {
  switch (state.status) {
    case "idle":
      return "idle";
    case "ready":
      return state.data.id;
    case "failed":
      return state.message;
    case "cancelled":
      return "cancelled=" + state.reason;
    default: {
      const exhaustive: never = state;
      throw new Error("unhandled state: " + JSON.stringify(exhaustive));
    }
  }
}

const valid: unknown = { id: "WO-1", title: "Inspect pump", priority: "low" };
const invalid: unknown = { id: "WO-2", title: 17, priority: "urgent" };

console.log("valid=" + isWorkOrder(valid));
console.log("invalid=" + isWorkOrder(invalid));
console.log(renderState({ status: "cancelled", reason: "user-request" }));
console.log("MODELING_NARROWING_EXERCISE_PASS");
