import { expect, it } from "vitest";
import { summarizeWorkOrders } from "../src/work-order-summary.mjs";

// This fault injects an expected value unrelated to the hand-calculated two-row fixture.
it("UNTRUSTED_ORACLE_WRONG_EXPECTED_VALUE", () => {
  const result = summarizeWorkOrders([
    { id: "WO-1", status: "CREATED" },
    { id: "WO-2", status: "ASSIGNED" },
  ]);
  expect(result.total, "UNTRUSTED_ORACLE_WRONG_EXPECTED_VALUE").toBe(99);
});
