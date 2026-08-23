import assert from "node:assert/strict";

// The injected fault strips the receiver from a normal prototype method in strict ESM.
const behavior = {
  summary() {
    return this.id;
  },
};
const workOrder = Object.assign(Object.create(behavior), { id: "WO-1" });
const detached = workOrder.summary;
let detachedFailed = false;
try {
  detached();
} catch {
  detachedFailed = true;
}
assert.equal(detachedFailed, false, "THIS_BINDING_LOSS_DETACHED_METHOD");
