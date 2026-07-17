// Responsibility: prove the safe model accepts one valid payload, rejects malformed variants, and renders all states.
// Data source: a deterministic matrix covers records, null, arrays, inherited fields, and wrong enum values.
// Mapping: each fixture maps to an expected boolean; trusted values map through all discriminated branches.
// Side effects: writes one pass marker after every assertion succeeds.

import { parseWorkOrder, renderState } from "./model.js";

const inherited = Object.create({ id: "WO-INHERITED" }) as Record<string, unknown>;
inherited.title = "Inherited id";
inherited.priority = "low";

const cases: readonly [unknown, boolean][] = [
  [{ id: "WO-1", title: "Inspect pump", priority: "low" }, true],
  [{ id: "", title: "Inspect pump", priority: "low" }, false],
  [{ id: "WO-2", title: "Inspect pump", priority: "urgent" }, false],
  [{ id: "WO-3", priority: "high" }, false],
  [null, false],
  [[], false],
  [inherited, false]
];

for (const [input, expected] of cases) {
  if ((parseWorkOrder(input) !== undefined) !== expected) {
    throw new Error("guard matrix mismatch");
  }
}

const labels = [
  renderState({ status: "idle" }),
  renderState({ status: "loading", requestId: "REQ-1" }),
  renderState({
    status: "ready",
    data: { id: "WO-1", title: "Inspect pump", priority: "low" }
  }),
  renderState({ status: "failed", message: "timeout", retryable: true })
];

if (labels.join("|") !== "idle|loading:REQ-1|ready:WO-1|retry:timeout") {
  throw new Error("state render mismatch");
}

console.log("MODELING_NARROWING_LAB_BASELINE_PASS");
