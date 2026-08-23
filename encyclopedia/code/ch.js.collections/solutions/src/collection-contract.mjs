import assert from "node:assert/strict";

// buildCollectionView implements the exercise contract while keeping caller-owned values read-only.
function buildCollectionView(input, updates) {
  const updated = input.map((workOrder) => {
    const patch = updates.get(workOrder.id) ?? {};
    return {
      ...workOrder,
      ...patch,
      // The patch is applied after source metadata inside a newly owned nested object.
      metadata: {
        ...(workOrder.metadata ?? {}),
        ...(patch.metadata ?? {}),
      },
    };
  });

  const groups = new Map();
  for (const workOrder of updated) {
    const status = workOrder.status ?? "UNSPECIFIED";
    if (!groups.has(status)) {
      groups.set(status, []);
    }
    groups.get(status).push(workOrder);
  }
  const uniqueIds = [...new Set(updated.map(({ id }) => id))];
  return { updated, groups, uniqueIds };
}

const empty = buildCollectionView([], new Map());
assert.equal(empty.groups.size, 0);
assert.deepEqual(empty.uniqueIds, []);

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
const result = buildCollectionView(input, updates);

assert.equal(JSON.stringify(input), before);
assert.deepEqual(
  [...result.groups].map(([status, group]) => [status, group.length]),
  [["CREATED", 2], ["IN_PROGRESS", 1], ["UNSPECIFIED", 1]],
);
assert.deepEqual(result.uniqueIds, ["WO-1", "WO-2", "WO-3"]);
assert.notStrictEqual(result.updated, input);
assert.notStrictEqual(result.updated[0], input[0]);
assert.notStrictEqual(result.updated[0].metadata, input[0].metadata);
assert.equal(result.updated[1].metadata.source, "mobile");

console.log(
  `groups=${[...result.groups]
    .map(([status, group]) => `${status}:${group.length}`)
    .join("|")}`,
);
console.log(`unique=${result.uniqueIds.join(">")}`);
console.log("input=unchanged");
console.log("references=new");
