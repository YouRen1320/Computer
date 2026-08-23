// Responsibility: expose an incorrect whole-union expectation for a distributive conditional type.
// Data source: the compile fixture supplies the union string | number to a naked type parameter.
// Mapping: each union member maps separately to text or other, producing a wider result than expected.
// Side effects: none; this file must fail static compilation with TS2322.

type Category<T> = T extends string ? "text" : "other";
type Distributed = Category<string | number>;

const expectedWholeResult: "other" = null as unknown as Distributed;
void expectedWholeResult;
