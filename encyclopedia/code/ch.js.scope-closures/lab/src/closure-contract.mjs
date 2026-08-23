import assert from "node:assert/strict";

// 每次工厂调用创建独立 count 绑定，返回方法闭合本次调用环境。
function createCounter(name) {
  let count = 0;

  function increment() {
    count += 1;
    return `${name}:${count}`;
  }

  function read() {
    return count;
  }

  return { increment, read };
}

const first = createCounter("first");
const second = createCounter("second");

// 交叉断言固定 env-first 与 env-second 的独立调用时序。
assert.equal(first.read(), 0, "FIRST_INITIAL_STATE_MISMATCH");
assert.equal(second.read(), 0, "SECOND_INITIAL_STATE_MISMATCH");
assert.equal(first.increment(), "first:1", "FIRST_INCREMENT_ONE_MISMATCH");
assert.equal(second.read(), 0, "SECOND_CHANGED_AFTER_FIRST_CALL");
assert.equal(first.increment(), "first:2", "FIRST_INCREMENT_TWO_MISMATCH");
assert.equal(second.increment(), "second:1", "SECOND_INCREMENT_ONE_MISMATCH");
assert.equal(first.read(), 2, "FIRST_FINAL_STATE_MISMATCH");
assert.equal(second.read(), 1, "SECOND_FINAL_STATE_MISMATCH");

// stdout 是隔离矩阵的紧凑预言，详细分歧由断言消息提供。
console.log(`isolation=PASS,first=${first.read()},second=${second.read()}`);
