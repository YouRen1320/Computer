import assert from "node:assert/strict";

// 固定输入覆盖 canonical 矩阵，不依赖真实 FactoryCare 数据。
const numberValue = 42;
const stringValue = "42";
const booleanValue = false;
const nullValue = null;
const undefinedValue = undefined;
const nanValue = Number("bad");

// 严格断言逐项固定值、类型和特殊值验证方法。
assert.equal(numberValue, 42, "NUMBER_VALUE_MISMATCH");
assert.equal(typeof numberValue, "number", "NUMBER_TYPE_MISMATCH");
assert.equal(stringValue, "42", "STRING_VALUE_MISMATCH");
assert.equal(typeof stringValue, "string", "STRING_TYPE_MISMATCH");
assert.equal(booleanValue, false, "BOOLEAN_VALUE_MISMATCH");
assert.equal(typeof booleanValue, "boolean", "BOOLEAN_TYPE_MISMATCH");
assert.equal(nullValue, null, "NULL_VALUE_MISMATCH");
assert.equal(typeof nullValue, "object", "TYPEOF_NULL_ORACLE_MISMATCH");
assert.equal(undefinedValue, undefined, "UNDEFINED_VALUE_MISMATCH");
assert.equal(typeof undefinedValue, "undefined", "UNDEFINED_TYPE_MISMATCH");
assert.equal(Number.isNaN(nanValue), true, "NAN_PROBE_MISMATCH");
assert.equal(typeof nanValue, "number", "NAN_TYPE_MISMATCH");
assert.equal(Number(stringValue), 42, "EXPLICIT_CONVERSION_MISMATCH");
assert.equal(stringValue === numberValue, false, "STRICT_EQUALITY_MISMATCH");
assert.equal(0 ?? 30, 0, "NULLISH_ZERO_MISMATCH");

// stdout 是绿色矩阵的紧凑结果，详细失败由断言消息给出。
console.log("matrix=PASS");
