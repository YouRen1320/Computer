import assert from "node:assert/strict";

// buildCollectionView owns only newly created containers; input records remain borrowed read-only data.
function buildCollectionView(input, updates = new Map()) {
  const updated = input.map((workOrder) => {
    const patch = updates.get(workOrder.id) ?? {};
    return {
      ...workOrder,
      ...patch,
      // Copy the writable nested path so patches cannot write through to the source record.
      metadata: {
        ...(workOrder.metadata ?? {}),
        ...(patch.metadata ?? {}),
      },
    };
  });

  const byStatus = new Map();
  const seenIds = new Set();
  const unique = [];
  for (const workOrder of updated) {
    const statusKey = workOrder.status ?? "UNSPECIFIED";
    if (!byStatus.has(statusKey)) {
      byStatus.set(statusKey, []);
    }
    byStatus.get(statusKey).push(workOrder);
    if (!seenIds.has(workOrder.id)) {
      seenIds.add(workOrder.id);
      unique.push(workOrder);
    }
  }
  return { updated, byStatus, unique };
}

// The fixture combines arrival order, duplicate identity, a missing status, and an update.
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

const empty = buildCollectionView([]);
assert.deepEqual([...empty.byStatus.keys()], []);
assert.deepEqual(empty.unique, []);
assert.notStrictEqual(empty.updated, input);

const result = buildCollectionView(input, updates);
assert.equal(result.updated.length, 4);
assert.deepEqual([...result.byStatus.keys()], ["CREATED", "IN_PROGRESS", "UNSPECIFIED"]);
assert.deepEqual(
  [...result.byStatus].map(([status, group]) => [status, group.length]),
  [["CREATED", 2], ["IN_PROGRESS", 1], ["UNSPECIFIED", 1]],
);
assert.deepEqual(result.unique.map(({ id }) => id), ["WO-1", "WO-2", "WO-3"]);
assert.equal(result.updated[1].metadata.source, "mobile");
assert.notStrictEqual(result.updated, input);
assert.notStrictEqual(result.updated[1], input[1]);
assert.notStrictEqual(result.updated[1].metadata, input[1].metadata);
assert.equal(JSON.stringify(input), before);

// Stable scalar lines avoid runtime-specific Map and object pretty-printing.
console.log(`input-length=${input.length}`);
console.log(`status-order=${[...result.byStatus.keys()].join(">")}`);
console.log(
  `status-counts=${[...result.byStatus]
    .map(([status, group]) => `${status}:${group.length}`)
    .join("|")}`,
);
console.log(`unique-ids=${result.unique.map(({ id }) => id).join(">")}`);
console.log(`outer-new=${result.updated !== input}`);
console.log(`nested-update-new=${result.updated[1].metadata !== input[1].metadata}`);
console.log(`input-unchanged=${JSON.stringify(input) === before}`);
