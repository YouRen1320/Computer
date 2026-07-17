import assert from "node:assert/strict";

// transform constructs grouping and uniqueness views while treating every input snapshot as borrowed data.
function transform(input, updates = new Map()) {
  const updated = input.map((workOrder) => {
    const patch = updates.get(workOrder.id) ?? {};
    return {
      ...workOrder,
      ...patch,
      // Merge the only writable nested path into a new object.
      metadata: {
        ...(workOrder.metadata ?? {}),
        ...(patch.metadata ?? {}),
      },
    };
  });

  const groups = new Map();
  const seenIds = new Set();
  const unique = [];
  for (const workOrder of updated) {
    const status = workOrder.status ?? "UNSPECIFIED";
    if (!groups.has(status)) {
      groups.set(status, []);
    }
    groups.get(status).push(workOrder);
    if (!seenIds.has(workOrder.id)) {
      seenIds.add(workOrder.id);
      unique.push(workOrder);
    }
  }
  return { updated, groups, unique };
}

const empty = transform([]);
assert.equal(empty.groups.size, 0);
assert.equal(empty.unique.length, 0);
assert.deepEqual(empty.updated, []);

// This single fixture exercises duplicate, missing-key, and update branches.
const input = [
  { id: "WO-1", status: "CREATED", metadata: { source: "scan" } },
  { id: "WO-2", status: "ASSIGNED", metadata: { source: "desk" } },
  { id: "WO-1", status: "CREATED", metadata: { source: "retry" } },
  { id: "WO-3", metadata: { source: "import" } },
];
const before = JSON.stringify(input);
const updates = new Map([
  ["WO-2", { status: "IN_PROGRESS", metadata: { source: "mobile" } }],
]);
const result = transform(input, updates);

assert.equal(result.updated.length, input.length);
assert.deepEqual([...result.groups.keys()], ["CREATED", "IN_PROGRESS", "UNSPECIFIED"]);
assert.deepEqual([...result.groups].map(([key, value]) => [key, value.length]), [
  ["CREATED", 2],
  ["IN_PROGRESS", 1],
  ["UNSPECIFIED", 1],
]);
assert.deepEqual(result.unique.map(({ id }) => id), ["WO-1", "WO-2", "WO-3"]);
assert.equal(result.groups.get("UNSPECIFIED")[0].id, "WO-3");
assert.equal(result.updated[1].status, "IN_PROGRESS");
assert.equal(result.updated[1].metadata.source, "mobile");
assert.notStrictEqual(result.updated, input);
assert.notStrictEqual(result.updated[1], input[1]);
assert.notStrictEqual(result.updated[1].metadata, input[1].metadata);
assert.equal(JSON.stringify(input), before);

console.log("case-empty=groups:0,unique:0");
console.log(
  `case-duplicate=groups:${[...result.groups]
    .map(([status, group]) => `${status}:${group.length}`)
    .join("|")}`,
);
console.log("case-missing=status:UNSPECIFIED");
console.log(
  `case-update=${result.updated[1].id}:${result.updated[1].status}:${result.updated[1].metadata.source}`,
);
console.log("case-identity=outer:new,record:new,metadata:new");
console.log("case-input=unchanged");
