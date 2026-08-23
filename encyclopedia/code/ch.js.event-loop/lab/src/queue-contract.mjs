// The baseline records queue order and an awaited rejection boundary as primitive evidence.
const trace = ["sync:start"];
setTimeout(() => trace.push("task:timer"), 0);
Promise.resolve().then(() => trace.push("microtask:promise"));
queueMicrotask(() => trace.push("microtask:queue"));

async function resume() {
  trace.push("async:before");
  await null;
  trace.push("async:after");
}

const completion = resume();
trace.push("sync:end");
await completion;
await new Promise((resolve) => setTimeout(resolve, 10));

// Await makes the rejection observable in this explicit local catch boundary.
try {
  await Promise.reject(new Error("ASYNC_BOUNDARY"));
} catch (error) {
  trace.push(`error=${error.message}`);
}

console.log(trace.join("\n"));
