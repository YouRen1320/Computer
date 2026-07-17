// Responsibility: keep the repaired public API honest by passing a key outside WorkOrder.
// Data source: a complete WorkOrder fixture and the literal missing key form the negative case.
// Mapping: the key constraint must reject missing before any runtime property access can occur.
// Side effects: none; a completed exercise still compiles this file to an intentional TS2345 failure.

import { selectField, type WorkOrder } from "../src/exercise.js";

const order: WorkOrder = {
  id: "WO-31",
  title: "Inspect motor",
  priority: "high",
  completed: false
};

selectField(order, "missing");
