import assert from "node:assert/strict";

function createCounter() {
  let count = 0;

  function increment() {
    // 局部 count 故意遮蔽工厂 count，返回 11 却不改变 read 所见状态。
    let count = 10;
    count += 1;
    return count;
  }

  return { increment, read: () => count };
}

const counter = createCounter();
counter.increment();

// 合同要求 increment 更新工厂状态；read 实际仍为 0。
assert.equal(counter.read(), 1, "SHADOWING_UPDATED_WRONG_BINDING");
