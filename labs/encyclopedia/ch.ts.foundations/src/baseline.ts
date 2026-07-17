import { buildLabels, normalizeNumericId } from "./work-orders.js";

// This is the known-good input that must remain green while fault fixtures fail.
const orders: {
  readonly id: string;
  status: string;
  assignee?: string;
}[] = [
  { id: "WO-1", status: "OPEN", assignee: "Lin" },
  { id: "WO-2", status: "CLOSED" }
];
const labels = buildLabels(orders, (id, status, owner) => id + ":" + status + ":" + owner);

if (
  labels.join("|") !== "WO-1:OPEN:Lin|WO-2:CLOSED:UNASSIGNED" ||
  normalizeNumericId(9) !== "WO-9"
) {
  throw new Error("LAB_TYPESCRIPT_BASELINE_INVALID");
}

console.log("LAB_TYPESCRIPT_BASELINE_PASS");
