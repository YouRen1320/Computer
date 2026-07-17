import assert from "node:assert/strict";

// TODO：这个模块级计数会让所有工厂实例共享状态，应放入每次工厂调用环境。
let sharedCount = 0;

function createCounter(name) {
  return {
    increment() {
      sharedCount += 1;
      return `${name}:${sharedCount}`;
    },
    read() {
      return sharedCount;
    },
  };
}

const first = createCounter("first");
const second = createCounter("second");
first.increment();

// 第一项合同要求未调用的 second 仍为 0，稳定暴露状态层级错误。
assert.equal(second.read(), 0, "SHARED_STATE_EXERCISE");

function createShadowCounter() {
  let count = 0;

  function increment() {
    // TODO：局部 count 遮蔽了应更新的工厂 count。
    let count = 10;
    count += 1;
    return count;
  }

  return { increment, read: () => count };
}

const shadowCounter = createShadowCounter();
shadowCounter.increment();
assert.equal(shadowCounter.read(), 1, "SHADOWING_EXERCISE");

let readFirst;
let readSecond;

// TODO：var 让两个回调共享循环结束后的 index，应使用每轮独立绑定。
for (var index = 0; index < 2; index += 1) {
  if (index === 0) {
    readFirst = () => index;
  } else {
    readSecond = () => index;
  }
}

assert.equal(readFirst(), 0, "LOOP_CAPTURE_EXERCISE");
assert.equal(readSecond(), 1, "LOOP_CAPTURE_SECOND_EXERCISE");

// stdout 只在三个环境合同全部通过后产生。
console.log(`first=${first.read()},second=${second.read()},shadow=${shadowCounter.read()},loop=${readFirst()},${readSecond()}`);
