import assert from "node:assert/strict";

// 50 是 P2 下界；这条故障链故意省略中间分支。
const score = 50;
let priority = "P3";
if (score >= 80) {
  priority = "P1";
} else {
  priority = "P3";
}

// 边界表要求 score=50 得到 P2，消息标识遗漏分支。
assert.equal(priority, "P2", "MISSING_P2_BRANCH_AT_BOUNDARY");
