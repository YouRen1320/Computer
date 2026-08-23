import assert from "node:assert/strict";

// 状态故意声明在工厂外，使所有返回方法闭合同一个模块绑定。
let sharedCount = 0;

function createCounter() {
  return {
    increment() {
      sharedCount += 1;
      return sharedCount;
    },
    read() {
      return sharedCount;
    },
  };
}

const first = createCounter();
const second = createCounter();
first.increment();

// 第二实例从未调用却读到 1，稳定暴露共享状态泄漏。
assert.equal(second.read(), 0, "UNEXPECTED_SHARED_CLOSURE_STATE");
