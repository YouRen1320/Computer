import { describe, expect, it, vi } from "vitest";
import { loadSummary, summarizeWorkOrders } from "../src/work-order-summary.mjs";

// freshOrders ensures every test receives an isolated mutable fixture.
function freshOrders() {
  return [
    { id: "WO-1", status: "CREATED" },
    { id: "WO-2", status: "ASSIGNED" },
    { id: "WO-3", status: "CREATED" },
  ];
}

describe("exercise oracle", () => {
  it("counts the three-row normal case", () => {
    const result = summarizeWorkOrders(freshOrders());
    // TODO: replace the invented number with the independently hand-calculated total.
    expect(result.total, "UNTRUSTED_ORACLE_EXERCISE").toBe(99);
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
