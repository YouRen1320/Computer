import { expect, it } from "vitest";

// This fault lets the test callback finish without returning or awaiting its rejecting matcher.
it("FALSE_POSITIVE_UNAWAITED_ASYNC_ASSERTION", () => {
  expect(Promise.reject(new Error("offline"))).rejects.toThrow("different message");
});
