import { expect, it } from "vitest";
import { summarizeWorkOrders } from "../src/work-order-summary.mjs";

// hasAssertions converts an otherwise silent catch false positive into a deterministic failure.
it("FALSE_POSITIVE_CAUGHT_ERROR_SILENT", () => {
  expect.hasAssertions();
  try {
    summarizeWorkOrders(null);
  } catch {
    // Injected fault: the exception is swallowed without checking its contract.
  }
});
