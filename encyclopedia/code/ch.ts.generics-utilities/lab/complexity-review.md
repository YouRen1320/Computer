# Type simplification review

- Public operations: `selectFields` combines one key constraint with `Pick`; `WorkOrderPatch` combines `Partial` with `Omit`.
- Complexity ceiling: no recursive type and no conditional nesting beyond one level in production source.
- Assertion boundary: one local incremental-initialization assertion inside `selectFields`; callers never assert the result.
- Simpler alternative considered: explicit selectors are preferred when a domain has only one stable field set.
- Runtime invariant: every requested key is copied and a WorkOrder patch cannot replace `id` through its public type.
- Review trigger: replace the generic API with explicit functions if diagnostics cease to point at the calling key.
