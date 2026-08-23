import assert from "node:assert/strict";

let sharedCallCount = 0;

// 格式化函数按“工单号、状态”位置合同返回稳定文本。
function formatWorkOrder(workOrderId, status) {
  return `${workOrderId}:${status}`;
}

// 纯合计函数把计算值显式返回，不通过日志传递结果。
function totalMinutes(activeMinutes, reviewMinutes) {
  const total = activeMinutes + reviewMinutes;
  return total;
}

// 纯优先级格式化只依赖显式输入，不修改模块级验证计数。
function formatPriority(priority) {
  return `priority=${priority}`;
}

const summary = formatWorkOrder("WO-1001", "CREATED");
assert.equal(summary, "WO-1001:CREATED", "PARAMETER_ORDER_EXERCISE");
assert.equal(totalMinutes(35, 5), 40, "MISSING_RETURN_EXERCISE");
assert.equal(formatPriority("P1"), "priority=P1", "FORMAT_RESULT_EXERCISE");
assert.equal(sharedCallCount, 0, "SHARED_SIDE_EFFECT_EXERCISE");

// stdout 与公开练习共享同一最终预言。
console.log(`${summary},total=40,priority=P1`);
