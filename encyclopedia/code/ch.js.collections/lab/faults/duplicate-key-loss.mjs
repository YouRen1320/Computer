import assert from "node:assert/strict";

// This injected fault maps a status to one record, so the later record overwrites its predecessor.
const input = [
  { id: "WO-1-A", status: "CREATED" },
  { id: "WO-1-B", status: "CREATED" },
];
const byStatus = {};
for (const workOrder of input) {
  byStatus[workOrder.status] = workOrder;
}
assert.equal(byStatus.CREATED.id, "WO-1-A", "DUPLICATE_KEY_LOSS_OVERWROTE_FIRST");
