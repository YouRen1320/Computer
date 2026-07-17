import assert from "node:assert/strict";

// 分类函数只根据显式分数输入返回教学优先级。
function classifyPriority(score) {
  if (score >= 80) {
    return "P1";
  }
  if (score >= 50) {
    return "P2";
  }
  return "P3";
}

// 函数表达式返回分钟合计，默认参数仅处理缺失 reviewMinutes。
const totalMinutes = function (activeMinutes, reviewMinutes = 0) {
  return activeMinutes + reviewMinutes;
};

// 回调入口的合同是同步调用 formatter 一次，并返回它的结果。
function applyFormatter(value, formatter) {
  return formatter(value);
}

let callbackCallCount = 0;
const formatter = (priority) => {
  // 这是验证调用次数的显式测试副作用，不属于纯分类函数。
  callbackCallCount += 1;
  return `priority=${priority}`;
};

// 输入输出表覆盖阈值、默认参数和同一输入重复计算。
assert.equal(classifyPriority(80), "P1", "CLASSIFY_80_MISMATCH");
assert.equal(classifyPriority(79), "P2", "CLASSIFY_79_MISMATCH");
assert.equal(classifyPriority(49), "P3", "CLASSIFY_49_MISMATCH");
assert.equal(totalMinutes(35), 35, "DEFAULT_PARAMETER_MISMATCH");
assert.equal(totalMinutes(35, 5), 40, "TWO_ARGUMENT_TOTAL_MISMATCH");
assert.equal(totalMinutes(35, 5), 40, "PURE_REPEAT_RESULT_MISMATCH");

// 回调结果和调用计数必须同时满足合同。
assert.equal(applyFormatter("P1", formatter), "priority=P1", "CALLBACK_RESULT_MISMATCH");
assert.equal(callbackCallCount, 1, "CALLBACK_COUNT_MISMATCH");

console.log(`contracts=PASS,callbackCalls=${callbackCallCount}`);
