// Responsibility: expose a generic implementation that reads id without declaring that capability.
// Data source: the unconstrained type parameter T is the entire static negative fixture.
// Mapping: the implementation incorrectly assumes every possible T has an id property.
// Side effects: none; this file must fail static compilation with TS2339.

function readId<T>(value: T): string {
  return String(value.id);
}

void readId;
