import assert from "node:assert/strict";

// existingMinutes 是数字，新输入仍是字符串；加号故意触发字符串连接。
const existingMinutes = 5;
const rawAdditionalMinutes = "1";
const totalMinutes = existingMinutes + rawAdditionalMinutes;

// 业务预期为数字 6，实际为字符串 "51"，消息标识首个合同分歧。
assert.equal(totalMinutes, 6, "IMPLICIT_PLUS_COERCION_CHANGED_RESULT");
