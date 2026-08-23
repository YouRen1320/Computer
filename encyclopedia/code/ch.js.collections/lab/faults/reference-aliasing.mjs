import assert from "node:assert/strict";

// This injected fault copies only the outer record and leaves metadata aliased to the source.
const original = {
  id: "WO-2",
  status: "ASSIGNED",
  metadata: { source: "desk" },
};
const shallowCopy = { ...original };
assert.notStrictEqual(shallowCopy.metadata, original.metadata, "REFERENCE_ALIASING_NESTED_PATH");
