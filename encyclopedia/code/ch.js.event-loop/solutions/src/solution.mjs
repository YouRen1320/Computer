// queueTrace owns registrations and waits for their real completion promises before returning evidence.
async function queueTrace() {
  const trace = ["sync:start"];
  setTimeout(() => trace.push("task:timer"), 0);
  Promise.resolve().then(() => trace.push("microtask:promise"));
  queueMicrotask(() => trace.push("microtask:queue"));

  async function countCreated() {
    trace.push("async:before");
    await null;
    trace.push("async:after");
    return 3;
  }

  const countPromise = countCreated();
  trace.push("sync:end");
  const count = await countPromise;
  await new Promise((resolve) => setTimeout(resolve, 10));
  return { trace, count };
}

// rejectionEvidence keeps the catch at the owner that awaits the failing asynchronous operation.
async function rejectionEvidence() {
  try {
    await (async () => {
      await null;
      throw new Error("ASYNC_BOUNDARY");
    })();
    return "missing";
  } catch (error) {
    return error.message;
  }
}

const { trace, count } = await queueTrace();
const rejection = await rejectionEvidence();
console.log(trace.join("\n"));
console.log(`count=${count}`);
console.log(`rejection=${rejection}`);
