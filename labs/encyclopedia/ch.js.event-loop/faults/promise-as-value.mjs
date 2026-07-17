// This fault treats an async function's Promise object as if it were the fulfilled number.
async function countOrders() {
  return 3;
}

const actual = countOrders();
const mistaken = typeof actual !== "number";
await actual;

if (mistaken) {
  console.error(`PROMISE_AS_SYNC_VALUE actualType=${typeof actual}`);
  process.exitCode = 1;
} else {
  console.error("FAULT_SETUP_FAILED promise looked synchronous");
  process.exitCode = 2;
}
