import { describe, expect, it, vi } from "vitest";
import { loadSummary, summarizeWorkOrders } from "../src/work-order-summary.mjs";

// freshOrders prevents test-order dependence by allocating every mutable fixture per call.
function freshOrders() {
  return [
    { id: "WO-1", status: "CREATED" },
    { id: "WO-2", status: "ASSIGNED" },
    { id: "WO-3", status: "CREATED" },
  ];
}

describe("baseline summary contract", () => {
  it("counts the normal case", () => {
    expect(summarizeWorkOrders(freshOrders())).toStrictEqual({
      total: 3,
      counts: { CREATED: 2, ASSIGNED: 1 },
      ids: ["WO-1", "WO-2", "WO-3"],
    });
  });

  it("handles empty input", () => {
    expect(summarizeWorkOrders([])).toStrictEqual({ total: 0, counts: {}, ids: [] });
  });

  it("rejects non-array input", () => {
    expect(() => summarizeWorkOrders(undefined)).toThrow("workOrders must be an array");
  });

  it("rejects missing status", () => {
    expect(() => summarizeWorkOrders([{ id: "WO-1" }])).toThrow(TypeError);
  });

  it("does not mutate input", () => {
    const input = freshOrders();
    const before = structuredClone(input);
    summarizeWorkOrders(input);
    expect(input).toStrictEqual(before);
  });

  it("awaits the injected loader", async () => {
    const loadOrders = vi.fn().mockResolvedValue(freshOrders());
    await expect(loadSummary(loadOrders)).resolves.toMatchObject({ total: 3 });
    expect(loadOrders).toHaveBeenCalledOnce();
  });

  it("preserves loader failure as cause", async () => {
    const cause = new Error("offline");
    const loadOrders = vi.fn().mockRejectedValue(cause);
    await expect(loadSummary(loadOrders)).rejects.toMatchObject({ cause });
  });
});
