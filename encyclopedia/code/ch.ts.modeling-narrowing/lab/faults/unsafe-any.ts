// Responsibility: show how any suppresses boundary checks and delays a malformed field failure.
// Data source: an any-typed fixture imitates an unchecked API response with a numeric title.
// Mapping: the unchecked title is treated as if it were a string even though no guard ran.
// Side effects: throws the stable runtime marker after the escaped value fails at runtime.

const payload: any = { id: "WO-ANY", title: 17 };

try {
  payload.title.toUpperCase();
} catch {
  throw new Error("UNSAFE_ANY_RUNTIME_FAULT");
}
