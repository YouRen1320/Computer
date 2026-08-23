// Responsibility: demonstrate exact selection, a locked-id patch, mapped event handlers, and infer-based extraction.
// Data source: one inline trusted WorkOrder and a validated internal priorityChanged event drive the example.
// Mapping: literal keys infer Pick fields; patch fields overlay the original while id remains outside the patch type.
// Side effects: dispatch invokes a handler and the program writes deterministic verifier evidence.

import {
  applyWorkOrderPatch,
  dispatchEvent,
  selectFields,
  type AwaitedValue,
  type Handlers,
  type WorkOrder,
  type WorkOrderEvent
} from "./tools.js";

const order: WorkOrder = {
  id: "WO-7",
  title: "Replace filter",
  priority: "high",
  completed: false
};

const selected = selectFields(order, ["id", "priority"] as const);
const exactSelection: Pick<WorkOrder, "id" | "priority"> = selected;
const patched = applyWorkOrderPatch(order, {
  title: "Replace cartridge",
  priority: "low"
});

let eventLine = "";
const handlers: Handlers<WorkOrderEvent> = {
  created: (event) => {
    eventLine = "created:" + event.order.id;
  },
  priorityChanged: (event) => {
    eventLine = event.id + ":" + event.priority;
  }
};

dispatchEvent<WorkOrderEvent>(
  { type: "priorityChanged", id: "WO-7", priority: "high" },
  handlers
);

type LoadedId = AwaitedValue<Promise<string>>;
const loadedId: LoadedId = exactSelection.id;
void loadedId;

console.log("selected=" + JSON.stringify(exactSelection));
console.log("patched=" + JSON.stringify(patched));
console.log("event=" + eventLine);
console.log("GENERICS_UTILITIES_EXAMPLE_PASS");
