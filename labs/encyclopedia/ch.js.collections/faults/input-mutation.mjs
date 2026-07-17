import assert from "node:assert/strict";

// This injected fault calls mutating sort on a caller-owned array.
const input = [{ id: "WO-2" }, { id: "WO-1" }];
const before = JSON.stringify(input);
input.sort((left, right) => left.id.localeCompare(right.id));
assert.equal(JSON.stringify(input), before, "INPUT_MUTATION_SORT_CHANGED_CALLER");
