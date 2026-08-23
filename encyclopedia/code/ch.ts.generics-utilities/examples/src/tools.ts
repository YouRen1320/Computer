// Responsibility: preserve object/key/value relationships and expose a deliberately small set of type transforms.
// Data source: callers provide a trusted object, a checked key tuple, a patch, or a validated event union.
// Mapping: K[number] becomes selected fields; Omit plus Partial becomes an editable WorkOrder patch.
// Side effects: selectFields allocates a new object and dispatchEvent invokes exactly one registered handler.

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
  // The local assertion covers incremental initialization; every requested key is copied below.
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

export type WorkOrderEvent =
  | { type: "created"; order: WorkOrder }
  | { type: "priorityChanged"; id: string; priority: WorkOrder["priority"] };

export type Handlers<E extends { type: PropertyKey }> = {
  [K in E["type"]]: (event: Extract<E, { type: K }>) => void;
};

export function dispatchEvent<E extends { type: PropertyKey }>(
  event: E,
  handlers: Handlers<E>
): void {
  // The mapped type relates each key to its member; runtime indexing cannot retain that correlation.
  const key = event.type as keyof Handlers<E>;
  const handler = handlers[key] as (value: E) => void;
  handler(event);
}

export type AwaitedValue<T> = T extends Promise<infer Value> ? Value : T;
