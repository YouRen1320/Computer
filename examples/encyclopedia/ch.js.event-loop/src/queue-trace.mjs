// runQueueTrace owns one deterministic trace; registrations are the input and stdout is the evidence.
async function runQueueTrace() {
  const trace = ["sync:start"];

  setTimeout(() => trace.push("task:timer"), 0);
  Promise.resolve().then(() => trace.push("microtask:promise"));
  queueMicrotask(() => trace.push("microtask:queue"));

  // The async function runs synchronously to await, then resumes as Promise-related work.
  async function resume() {
    trace.push("async:before");
    await null;
    trace.push("async:after");
  }

  const completion = resume();
  trace.push("sync:end");
  await completion;

  // This completion timer waits for the earlier timer without asserting an exact elapsed duration.
  await new Promise((resolve) => setTimeout(resolve, 10));
  return trace;
}

const trace = await runQueueTrace();
console.log(trace.join("\n"));
