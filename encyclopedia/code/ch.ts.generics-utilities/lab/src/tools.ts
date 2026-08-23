// Responsibility: implement the lab's exact field selector and domain-specific locked-id patch.
// Data source: callers provide a trusted object, a compile-time checked key tuple, and a WorkOrder patch.
// Mapping: K[number] determines Pick fields; Partial and Omit derive editable fields from WorkOrder.
// Side effects: both functions allocate fresh objects and do not mutate their inputs.

export interface WorkOrder {
  readonly id: string;
  title: string;
  priority: "low" | "high";
  completed: boolean;
}

export function selectFields<
  T extends object,
  const K extends readonly (keyof T)[]
>(object: T, keys: K): Pick<T, K[number]> {
  const selected = {} as Pick<T, K[number]>;
  for (const key of keys) {
    selected[key] = object[key];
  }
  return selected;
}

export type WorkOrderPatch = Partial<Omit<WorkOrder, "id">>;

export function applyWorkOrderPatch(
  current: WorkOrder,
  patch: WorkOrderPatch
): WorkOrder {
  return { ...current, ...patch };
}
