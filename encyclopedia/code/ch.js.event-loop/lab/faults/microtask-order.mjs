// This fault encodes the false prediction that a zero-delay timer beats already queued microtasks.
const trace = ["sync"];
setTimeout(() => trace.push("timer"), 0);
Promise.resolve().then(() => trace.push("promise"));
queueMicrotask(() => trace.push("queueMicrotask"));
await new Promise((resolve) => setTimeout(resolve, 10));

const actual = trace.join(">");
const invented = "sync>timer>promise>queueMicrotask";
if (actual !== invented) {
  console.error(`MICROTASK_ORDER_MISREAD actual=${actual}`);
  process.exitCode = 1;
} else {
  console.error("FAULT_SETUP_FAILED invented order unexpectedly matched");
  process.exitCode = 2;
}
