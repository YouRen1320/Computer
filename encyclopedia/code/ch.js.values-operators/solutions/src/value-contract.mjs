import assert from "node:assert/strict";

// 原始文本模拟表单输入；Number 在进入内部合同前显式转换它。
const rawRetryCount = "0";
const retryCount = Number(rawRetryCount);

// 内部值已同为 number，严格相等不会掩盖类型差异。
const isZero = retryCount === 0;

// 0 是合法配置；空值合并仅在 null/undefined 时使用默认值。
const effectiveRetryCount = retryCount ?? 3;

// 断言逐项固定历史 typeof 结果、内部类型、相等与回退合同。
assert.equal(typeof null, "object", "TYPEOF_NULL_ORACLE");
assert.equal(typeof retryCount, "number", "RETRY_COUNT_MUST_BE_NUMBER");
assert.equal(isZero, true, "STRICT_ZERO_MATCH_MISMATCH");
assert.equal(effectiveRetryCount, 0, "NULLISH_ZERO_MUST_BE_PRESERVED");

// stdout 是与公开练习共享的最终预言。
console.log(`retry=${effectiveRetryCount},type=${typeof effectiveRetryCount}`);
