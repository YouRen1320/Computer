// Responsibility: provide the safe baseline parser and exhaustive work-order state renderer.
// Data source: unknown decoded payloads enter parseWorkOrder; trusted state values enter renderState.
// Mapping: validated own fields form a fresh WorkOrder and the status tag selects exactly one branch.
// Side effects: the exhaustive fallback throws only for unchecked JavaScript that violates the union.

export interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
}

export type LoadState =
  | { status: "idle" }
  | { status: "loading"; requestId: string }
  | { status: "ready"; data: WorkOrder }
  | { status: "failed"; message: string; retryable: boolean };

function isRecord(value: unknown): value is Record<PropertyKey, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

export function parseWorkOrder(input: unknown): WorkOrder | undefined {
  if (
    !isRecord(input) ||
    !Object.hasOwn(input, "id") ||
    !Object.hasOwn(input, "title") ||
    !Object.hasOwn(input, "priority") ||
    typeof input.id !== "string" ||
    input.id.length === 0 ||
    typeof input.title !== "string" ||
    (input.priority !== "low" && input.priority !== "high")
  ) {
    return undefined;
  }
  return { id: input.id, title: input.title, priority: input.priority };
}

export function renderState(state: LoadState): string {
  switch (state.status) {
    case "idle":
      return "idle";
    case "loading":
      return "loading:" + state.requestId;
    case "ready":
      return "ready:" + state.data.id;
    case "failed":
      return (state.retryable ? "retry:" : "fatal:") + state.message;
    default: {
      const exhaustive: never = state;
      throw new Error("unhandled state: " + JSON.stringify(exhaustive));
    }
  }
}
