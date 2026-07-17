// Responsibility: exercise positive and negative guard cases and two loading-state variants.
// Data source: inline fixtures stand in for decoded API payloads and trusted application state.
// Mapping: parse success becomes a ready state while a known failure fixture maps directly to failed.
// Side effects: writes the deterministic evidence lines consumed by verify.sh.

import { parseWorkOrder, renderState } from "./model.js";

const validInput: unknown = {
  id: "WO-17",
  title: "Replace filter",
  priority: "high"
};
const invalidInput: unknown = {
  id: "WO-18",
  title: "Inspect motor",
  priority: "urgent"
};

const parsed = parseWorkOrder(validInput);
console.log("valid=" + (parsed !== undefined));
console.log("invalid=" + (parseWorkOrder(invalidInput) !== undefined));

if (parsed === undefined) {
  throw new Error("valid fixture was rejected");
}

console.log("ready=" + renderState({ status: "ready", data: parsed }));
console.log(
  "failed=" +
    renderState({ status: "failed", message: "gateway timeout", retryable: true })
);
console.log("MODELING_NARROWING_EXAMPLE_PASS");
