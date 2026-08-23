import assert from "node:assert/strict";

// 原始文本来自模拟表单；宽松相等故意把它与数字零折叠。
const rawRetryCount = "0";
const looselyMatchesZero = rawRetryCount == 0;

// 合同要求不同类型不能直接判为相同，因此此断言必须稳定失败。
assert.equal(looselyMatchesZero, false, "LOOSE_EQUALITY_COLLAPSED_TYPES");
