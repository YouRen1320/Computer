const rows = ["WO-1", "WO-2", "WO-3", "WO-4"].map((id) => ({
  id,
  accessibleName: "Open " + id
}));

class LayoutLedger {
  constructor() {
    // This state machine counts invalidating writes settled by later geometry reads.
    this.dirty = false;
    this.layouts = 0;
  }

  readGeometry() {
    if (this.dirty) {
      this.layouts += 1;
      this.dirty = false;
    }
    return 40;
  }

  writeLayoutStyle() {
    // This operation represents a geometry-affecting style write, not a transform-only update.
    this.dirty = true;
  }

  flushFrame() {
    if (this.dirty) {
      this.layouts += 1;
      this.dirty = false;
    }
  }
}

function scheduleRows(inputRows, ledger) {
  // TODO: snapshot every read first, then perform every write from that snapshot.
  inputRows.forEach(() => {
    ledger.writeLayoutStyle();
    ledger.readGeometry();
  });
  ledger.flushFrame();
}

const ledger = new LayoutLedger();
scheduleRows(rows, ledger);

// Resource cleanup is already correct; the exercise must not regress these guards.
const listenerDelta = 0;
const timerDelta = 0;
const order = rows.map((row) => row.id).join(",");
const namesValid = rows.every((row) => row.accessibleName.startsWith("Open WO-"));

if (
  ledger.layouts > 1 ||
  listenerDelta !== 0 ||
  timerDelta !== 0 ||
  order !== "WO-1,WO-2,WO-3,WO-4" ||
  !namesValid
) {
  console.error(
    "PERFORMANCE_BUDGET_EXERCISE layouts=" +
      ledger.layouts +
      " budget=1 listenerDelta=" +
      listenerDelta +
      " timerDelta=" +
      timerDelta
  );
  process.exit(1);
}

console.log("PERFORMANCE_BUDGET_PASS");
