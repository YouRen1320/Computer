import assert from "node:assert/strict";

let sharedCallCount = 0;

// 名为纯合计的函数故意修改模块级计数，制造意外共享副作用。
function totalMinutes(activeMinutes, reviewMinutes) {
  sharedCallCount += 1;
  return activeMinutes + reviewMinutes;
}

// 返回值正确仍不够；副作用合同要求共享计数保持 0。
assert.equal(totalMinutes(10, 2), 12, "TOTAL_RESULT_MISMATCH");
assert.equal(sharedCallCount, 0, "UNEXPECTED_SHARED_SIDE_EFFECT");
