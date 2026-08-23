// This fault proves that a synchronous try/catch cannot catch a rejection produced after await.
async function failLater() {
  await null;
  throw new Error("LATE_FAILURE");
}

let caughtLocally = false;
let pending;
try {
  pending = failLater();
} catch (_error) {
  caughtLocally = true;
}

const reason = await pending.catch((error) => error.message);
if (!caughtLocally && reason === "LATE_FAILURE") {
  console.error("ASYNC_ERROR_BOUNDARY_LOST");
  process.exitCode = 1;
} else {
  console.error(`FAULT_SETUP_FAILED caught=${caughtLocally} reason=${reason}`);
  process.exitCode = 2;
}
