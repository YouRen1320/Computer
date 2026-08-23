import assert from "node:assert/strict";

// 这个故障函数计算了 total，却没有把它返回给调用方。
function totalMinutes(activeMinutes, reviewMinutes) {
  const total = activeMinutes + reviewMinutes;
  void total;
}

// 调用结果实际为 undefined，断言消息定位返回合同缺失。
assert.equal(totalMinutes(10, 2), 12, "MISSING_RETURN_PRODUCED_UNDEFINED");
