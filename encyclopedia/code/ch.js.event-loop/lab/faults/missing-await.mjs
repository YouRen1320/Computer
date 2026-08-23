// This fault reads shared trace before the async operation reaches its completion marker.
async function runPipeline(trace) {
  trace.push("start");
  await null;
  trace.push("done");
}

const trace = [];
const pending = runPipeline(trace);
const observedTooEarly = trace.join(",") === "start";
await pending;

if (observedTooEarly && trace.join(",") === "start,done") {
  console.error("MISSING_AWAIT_ORDER");
  process.exitCode = 1;
} else {
  console.error(`FAULT_SETUP_FAILED trace=${trace.join(",")}`);
  process.exitCode = 2;
}
