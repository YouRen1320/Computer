// Responsibility: inject a selected key that is not part of the WorkOrder model.
// Data source: the local WorkOrder value and literal key tuple form the negative compile fixture.
// Mapping: the valid id key and invalid missing key are checked against keyof WorkOrder.
// Side effects: none; this file must fail static compilation with TS2322.

import { selectFields, type WorkOrder } from "../src/tools.js";

const order: WorkOrder = {
  id: "WO-1",
  title: "Inspect pump",
  priority: "low",
  completed: false
};

selectFields(order, ["id", "missing"] as const);
