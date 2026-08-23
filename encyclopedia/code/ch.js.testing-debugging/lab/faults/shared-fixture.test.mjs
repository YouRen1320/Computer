import { describe, expect, it } from "vitest";

// This module-level array deliberately leaks a mutation from the first sequential test to the second.
const sharedFixture = [{ id: "WO-1", status: "CREATED" }];

describe.sequential("shared fixture fault", () => {
  it("mutates shared setup", () => {
    sharedFixture.push({ id: "WO-2", status: "ASSIGNED" });
    expect(sharedFixture).toHaveLength(2);
  });

  it("TEST_ISOLATION_LEAK_SHARED_FIXTURE", () => {
    expect(sharedFixture, "TEST_ISOLATION_LEAK_SHARED_FIXTURE").toHaveLength(1);
  });
});
