// Responsibility: demonstrate a generic return assertion whose runtime object does not contain selected fields.
// Data source: a trusted WorkOrder-like value and the id key drive the falsely precise selection.
// Mapping: the broken implementation returns an uninitialized partial selection as a complete Pick<T, K>.
// Side effects: throws the stable runtime marker when the promised id is missing.

function brokenSelect<T, K extends keyof T>(
  object: T,
  keys: readonly K[]
): Pick<T, K> {
  void object;
  void keys;
  const incomplete: Partial<Pick<T, K>> = {};
  return incomplete as Pick<T, K>;
}

const selected = brokenSelect({ id: "WO-ASSERT" }, ["id"] as const);

if (selected.id === undefined) {
  throw new Error("OVERASSERTION_RUNTIME_FAULT");
}
