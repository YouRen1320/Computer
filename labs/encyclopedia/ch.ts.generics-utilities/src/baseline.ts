// Responsibility: prove exact inferred fields and unchanged-id patch behavior in the green baseline.
// Data source: one deterministic WorkOrder and literal key tuple supply all baseline input.
// Mapping: id and priority become the selected shape; title and completed become the patch overlay.
// Side effects: writes one pass marker after static assignments and runtime assertions succeed.

import {
  applyWorkOrderPatch,
  selectFields,
  type WorkOrder
} from "./tools.js";

const order: WorkOrder = {
  id: "WO-21",
  title: "Inspect fan",
  priority: "low",
  completed: false
};

const selected = selectFields(order, ["id", "priority"] as const);
const exact: Pick<WorkOrder, "id" | "priority"> = selected;
const patched = applyWorkOrderPatch(order, {
  title: "Inspect exhaust fan",
  completed: true
});

if (exact.id !== "WO-21" || exact.priority !== "low") {
  throw new Error("selected fields mismatch");
}
if (patched.id !== "WO-21" || patched.title !== "Inspect exhaust fan" || !patched.completed) {
  throw new Error("patch behavior mismatch");
}

console.log("GENERICS_UTILITIES_LAB_BASELINE_PASS");
