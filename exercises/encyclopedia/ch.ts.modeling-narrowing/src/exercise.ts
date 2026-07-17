// Responsibility: complete a trustworthy WorkOrder guard and an exhaustive loading-state renderer.
// Data source: inline unknown fixtures simulate decoded API input; the cancelled value is trusted state.
// Mapping: validated fields become WorkOrder and each status discriminant maps to a deterministic label.
// Side effects: writes the evidence output only after both compile-time and runtime obligations are met.

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

function isWorkOrder(value: unknown): value is WorkOrder {
  // TODO: replace this over-promising check with complete runtime evidence.
  return typeof value === "object" && value !== null && "id" in value;
}

function renderState(state: LoadState): string {
  switch (state.status) {
    case "idle":
      return "idle";
    case "ready":
      return state.data.id;
    case "failed":
      return state.message;
    // TODO: add the cancelled branch; do not weaken or cast the never check.
    default: {
      const exhaustive: never = state;
      return exhaustive;
    }
  }
}

const valid: unknown = { id: "WO-1", title: "Inspect pump", priority: "low" };
const invalid: unknown = { id: "WO-2", title: 17, priority: "urgent" };

console.log("valid=" + isWorkOrder(valid));
console.log("invalid=" + isWorkOrder(invalid));
console.log(renderState({ status: "cancelled", reason: "user-request" }));
console.log("MODELING_NARROWING_EXERCISE_PASS");
