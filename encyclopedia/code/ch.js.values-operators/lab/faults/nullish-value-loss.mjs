import assert from "node:assert/strict";

// 0 表示合法的“无需重试”；逻辑或故意把它当成 falsy 并替换。
const configuredRetries = 0;
const effectiveRetries = configuredRetries || 3;

// 合同要求保留零值，因此此断言必须以稳定消息失败。
assert.equal(effectiveRetries, 0, "NULLISH_FALLBACK_LOST_ZERO");
