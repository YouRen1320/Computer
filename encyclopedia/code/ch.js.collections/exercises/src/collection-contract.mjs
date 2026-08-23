import assert from "node:assert/strict";

// Exercise responsibility: repair ownership, grouping, and nested-copy defects without weakening the oracle.
function buildCollectionView(input, updates) {
  // TODO 1: replace this caller-owned mutation with a traversal that preserves arrival order.
  const updated = input
    .sort((left, right) => left.id.localeCompare(right.id))
    .map((workOrder) => {
      const patch = updates.get(workOrder.id) ?? {};
      return {
        ...workOrder,
        ...patch,
        // TODO 3: merge into a new nested object instead of retaining the source reference.
        metadata: workOrder.metadata,
      };
    });

  const groups = new Map();
  for (const workOrder of updated) {
    const status = workOrder.status ?? "UNSPECIFIED";
    // TODO 2: accumulate every record instead of overwriting its group.
    groups.set(status, [workOrder]);
  }

  // Primitive IDs make Set preserve the intended first-seen business identity.
  const uniqueIds = [...new Set(updated.map(({ id }) => id))];
  return { updated, groups, uniqueIds };
}

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

assert.equal(JSON.stringify(input), before, "INPUT_MUTATED_EXERCISE");
assert.deepEqual(
  [...result.groups].map(([status, group]) => [status, group.length]),
  [["CREATED", 2], ["IN_PROGRESS", 1], ["UNSPECIFIED", 1]],
  "DUPLICATE_KEY_LOSS_EXERCISE",
);
assert.notStrictEqual(
  result.updated[0].metadata,
  input[0].metadata,
  "REFERENCE_ALIASING_EXERCISE",
);
assert.deepEqual(result.uniqueIds, ["WO-1", "WO-2", "WO-3"]);
assert.equal(result.updated[1].metadata.source, "mobile");

console.log(
  `groups=${[...result.groups]
    .map(([status, group]) => `${status}:${group.length}`)
    .join("|")}`,
);
console.log(`unique=${result.uniqueIds.join(">")}`);
console.log("input=unchanged");
console.log("references=new");
