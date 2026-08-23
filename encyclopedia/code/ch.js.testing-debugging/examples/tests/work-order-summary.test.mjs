import { describe, expect, it, vi } from "vitest";
import { loadSummary, summarizeWorkOrders } from "../src/work-order-summary.mjs";

// freshOrders is the sole test-data source and returns new arrays plus new records for isolation.
function freshOrders() {
  return [
    { id: "WO-1", status: "CREATED" },
    { id: "WO-2", status: "ASSIGNED" },
    { id: "WO-3", status: "CREATED" },
  ];
}

describe("summarizeWorkOrders", () => {
  it("counts a discriminating normal fixture", () => {
    const result = summarizeWorkOrders(freshOrders());
    expect(result).toStrictEqual({
      total: 3,
      counts: { CREATED: 2, ASSIGNED: 1 },
      ids: ["WO-1", "WO-2", "WO-3"],
    });
  });

  it("returns the declared empty boundary", () => {
    expect(summarizeWorkOrders([])).toStrictEqual({ total: 0, counts: {}, ids: [] });
  });

  it("rejects a non-array input", () => {
    expect(() => summarizeWorkOrders(null)).toThrow(TypeError);
  });

  it("rejects a record without status", () => {
    expect(() => summarizeWorkOrders([{ id: "WO-1" }])).toThrow(
      "work order status is required",
    );
  });

  it("leaves caller-owned records unchanged", () => {
    const input = freshOrders();
    const before = structuredClone(input);
    summarizeWorkOrders(input);
    expect(input).toStrictEqual(before);
  });
});

describe("loadSummary boundary", () => {
  it("uses an injected loader once", async () => {
    const loadOrders = vi.fn().mockResolvedValue(freshOrders());
    await expect(loadSummary(loadOrders)).resolves.toMatchObject({ total: 3 });
    expect(loadOrders).toHaveBeenCalledOnce();
  });

  it("wraps a rejection and preserves cause", async () => {
    expect.assertions(2);
    const cause = new Error("offline");
    const loadOrders = vi.fn().mockRejectedValue(cause);
    await expect(loadSummary(loadOrders)).rejects.toMatchObject({
      message: "work-order summary load failed",
      cause,
    });
    expect(loadOrders).toHaveBeenCalledOnce();
  });
});
