import assert from "node:assert/strict";

// 合同要求 workOrderId 在前、status 在后。
function formatWorkOrder(workOrderId, status) {
  return `${workOrderId}:${status}`;
}

// 故意颠倒两个同为字符串的实参，运行时不会自动拒绝。
const actual = formatWorkOrder("CREATED", "WO-1001");
assert.equal(actual, "WO-1001:CREATED", "PARAMETER_ORDER_CONTRACT_VIOLATION");
