import {
  describeTransition,
  normalizeNumericId,
  summarizeOrders
} from "./work-orders.js";

// This literal is the checked work-order input for the example output.
const orders: {
  readonly id: string;
  status: string;
  assignee?: string;
}[] = [
  { id: "WO-1", status: "OPEN", assignee: "Lin" },
  { id: "WO-2", status: "CLOSED" }
];

const labels = summarizeOrders(
  orders,
  (id, status, owner) => id + ":" + status + ":" + owner
);

console.log("labels=" + labels.join("|"));
console.log("transition=" + describeTransition(["OPEN", "CLOSED"]));
console.log("numeric=" + normalizeNumericId(17));
console.log("TYPESCRIPT_FOUNDATIONS_PASS");
