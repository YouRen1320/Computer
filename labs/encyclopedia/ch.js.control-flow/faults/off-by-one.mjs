import assert from "node:assert/strict";

// retryCount=0 应执行零次；<= 故意让 index=0 进入一次。
const retryCount = 0;
let executionCount = 0;
for (let retryIndex = 0; retryIndex <= retryCount; retryIndex += 1) {
  executionCount += 1;
}

// 断言固定零次合同，稳定暴露循环上界偏一。
assert.equal(executionCount, 0, "OFF_BY_ONE_ZERO_EXECUTED_ONCE");
