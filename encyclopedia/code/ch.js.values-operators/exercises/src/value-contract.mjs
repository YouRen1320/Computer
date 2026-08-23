import assert from "node:assert/strict";

// rawRetryCount 模拟浏览器表单文本；TODO：在业务计算前显式转换为数字。
const rawRetryCount = "0";
const retryCount = rawRetryCount;

// TODO：转换后使用严格相等，避免宽松相等掩盖输入类型错误。
const isZero = retryCount == 0;

// TODO：0 是合法配置，应只在 null/undefined 时采用默认值。
const effectiveRetryCount = retryCount || 3;

// TODO：修正 null 的历史 typeof 结果，再逐项修复后续合同。
assert.equal(typeof null, "null", "TYPEOF_NULL_ORACLE");
assert.equal(typeof retryCount, "number", "RETRY_COUNT_MUST_BE_NUMBER");
assert.equal(isZero, true, "STRICT_ZERO_MATCH_MISMATCH");
assert.equal(effectiveRetryCount, 0, "NULLISH_ZERO_MUST_BE_PRESERVED");

// stdout 只在全部断言通过后产生，格式不能通过改预言绕开。
console.log(`retry=${effectiveRetryCount},type=${typeof effectiveRetryCount}`);
