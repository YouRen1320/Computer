// The exercise input is a fixed registration order; only the hand-written oracle is intentionally wrong.
const trace = ["sync:start"];
setTimeout(() => trace.push("task:timer"), 0);
Promise.resolve().then(() => trace.push("microtask:promise"));
queueMicrotask(() => trace.push("microtask:queue"));
trace.push("sync:end");
await new Promise((resolve) => setTimeout(resolve, 10));

// TODO: replace this invented order with the queue trace predicted from the registrations above.
const expected = [
  "sync:start",
  "sync:end",
  "task:timer",
  "microtask:promise",
  "microtask:queue",
];

const actualText = trace.join(">");
const expectedText = expected.join(">");
if (actualText !== expectedText) {
  throw new Error(`ASYNC_ORDER_MISREAD_EXERCISE: expected ${expectedText}; received ${actualText}`);
}

console.log(actualText);
