import { describe, expect, it, vi } from "vitest";
import { loadSummary, summarizeWorkOrders } from "../src/work-order-summary.mjs";

// freshOrders prevents test order from sharing arrays or records.
function freshOrders() {
  return [
    { id: "WO-1", status: "CREATED" },
    { id: "WO-2", status: "ASSIGNED" },
    { id: "WO-3", status: "CREATED" },
  ];
}

describe("repaired oracle", () => {
  it("counts the three-row normal case", () => {
    const result = summarizeWorkOrders(freshOrders());
    expect(result.total).toBe(3);
    expect(result.counts).toEqual({ CREATED: 2, ASSIGNED: 1 });
  });

  it("handles the empty boundary", () => {
    expect(summarizeWorkOrders([])).toStrictEqual({ total: 0, counts: {}, ids: [] });
  });

  it("rejects missing status", () => {
    expect(() => summarizeWorkOrders([{ id: "WO-1" }])).toThrow(TypeError);
  });

  it("does not mutate caller input", () => {
    const input = freshOrders();
    const before = structuredClone(input);
    summarizeWorkOrders(input);
    expect(input).toStrictEqual(before);
  });

  it("awaits and checks loader rejection", async () => {
    expect.assertions(2);
    const cause = new Error("offline");
    const loadOrders = vi.fn().mockRejectedValue(cause);
    await expect(loadSummary(loadOrders)).rejects.toMatchObject({ cause });
    expect(loadOrders).toHaveBeenCalledOnce();
  });
});
