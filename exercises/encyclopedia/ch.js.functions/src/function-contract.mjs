import assert from "node:assert/strict";

let sharedCallCount = 0;

// 合同规定第一个形参是工单号，第二个是状态。
function formatWorkOrder(workOrderId, status) {
  return `${workOrderId}:${status}`;
}

// TODO：函数计算 total 后必须把它返回给调用方。
function totalMinutes(activeMinutes, reviewMinutes) {
  const total = activeMinutes + reviewMinutes;
  void total;
}

// TODO：纯格式化函数不应修改模块级共享状态。
function formatPriority(priority) {
  sharedCallCount += 1;
  return `priority=${priority}`;
}

// TODO：按形参合同调整两个同类型实参的顺序。
const summary = formatWorkOrder("CREATED", "WO-1001");
assert.equal(summary, "WO-1001:CREATED", "PARAMETER_ORDER_EXERCISE");
assert.equal(totalMinutes(35, 5), 40, "MISSING_RETURN_EXERCISE");
assert.equal(formatPriority("P1"), "priority=P1", "FORMAT_RESULT_EXERCISE");
assert.equal(sharedCallCount, 0, "SHARED_SIDE_EFFECT_EXERCISE");

// stdout 只在全部函数合同通过后产生。
console.log(`${summary},total=40,priority=P1`);
