import assert from "node:assert/strict";

// 每次工厂调用创建独立 count，返回方法只闭合本次环境。
function createCounter(name) {
  let count = 0;

  return {
    increment() {
      count += 1;
      return `${name}:${count}`;
    },
    read() {
      return count;
    },
  };
}

const first = createCounter("first");
const second = createCounter("second");
first.increment();
assert.equal(second.read(), 0, "SHARED_STATE_EXERCISE");

function createShadowCounter() {
  let count = 0;

  function increment() {
    // 没有同名局部声明，赋值解析到工厂环境的 count。
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

// for-let 为每轮建立独立 index 绑定，两份回调分别捕获 0 和 1。
for (let index = 0; index < 2; index += 1) {
  if (index === 0) {
    readFirst = () => index;
  } else {
    readSecond = () => index;
  }
}

assert.equal(readFirst(), 0, "LOOP_CAPTURE_EXERCISE");
assert.equal(readSecond(), 1, "LOOP_CAPTURE_SECOND_EXERCISE");

// stdout 与公开练习共享同一环境追踪预言。
console.log(`first=${first.read()},second=${second.read()},shadow=${shadowCounter.read()},loop=${readFirst()},${readSecond()}`);
