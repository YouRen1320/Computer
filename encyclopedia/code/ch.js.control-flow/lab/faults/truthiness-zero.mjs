import assert from "node:assert/strict";

// 0 是合法的零次重试；Boolean(0) 故意把有效性错误地等同 truthiness。
const retryCount = 0;
const retryIsValid = Boolean(retryCount);

// 合同要求零值有效，因此断言稳定暴露 truthiness 误用。
assert.equal(retryIsValid, true, "TRUTHINESS_REJECTED_VALID_ZERO");
