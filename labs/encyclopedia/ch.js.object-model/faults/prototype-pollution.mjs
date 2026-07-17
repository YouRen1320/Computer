import assert from "node:assert/strict";

// The injected fault writes to a shared business prototype, causing an unrelated instance to drift.
const behavior = { kind: "work-order" };
const first = Object.create(behavior);
const second = Object.create(behavior);
const expectedSecondKind = second.kind;
Object.getPrototypeOf(first).kind = "polluted";
assert.equal(
  second.kind,
  expectedSecondKind,
  "PROTOTYPE_POLLUTION_SHARED_BEHAVIOR_DRIFT",
);
