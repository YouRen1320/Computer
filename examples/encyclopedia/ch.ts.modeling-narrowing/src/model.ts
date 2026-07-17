// Responsibility: define the trusted work-order model, runtime guard, and exhaustive state renderer.
// Data source: callers provide an unknown boundary value or an already validated loading state.
// Mapping: own JSON fields become a fresh WorkOrder; the status discriminant selects one render branch.
// Side effects: assertNever throws only if unvalidated JavaScript bypasses the closed TypeScript union.

export interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
}

export type WorkOrderLoadState =
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

function assertNever(value: never): never {
  throw new Error("unhandled state: " + JSON.stringify(value));
}

export function renderState(state: WorkOrderLoadState): string {
  switch (state.status) {
    case "idle":
      return "idle";
    case "loading":
      return "loading:" + state.requestId;
    case "ready":
      return state.data.id + ":" + state.data.title + ":" + state.data.priority;
    case "failed":
      return (state.retryable ? "retry:" : "fatal:") + state.message;
    default:
      return assertNever(state);
  }
}
