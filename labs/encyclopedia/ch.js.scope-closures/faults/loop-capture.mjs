import assert from "node:assert/strict";

let readFirst;
let readSecond;

// var index 是同一模块绑定，两份回调都将在循环后读取最终值 2。
for (var index = 0; index < 2; index += 1) {
  if (index === 0) {
    readFirst = () => index;
  } else {
    readSecond = () => index;
  }
}

// 合同预期每轮独立捕获 0/1，第一项立即暴露共享 var 绑定。
assert.equal(readFirst(), 0, "LOOP_CAPTURE_SHARED_FINAL_BINDING");
assert.equal(readSecond(), 1, "LOOP_CAPTURE_SECOND_BINDING");
