const mode = process.argv[2] ?? "baseline";
const rows = ["WO-1", "WO-2", "WO-3", "WO-4"];

class Ledger {
  constructor() {
    // dirty represents an invalidated geometry snapshot in the diagnostic model.
    this.dirty = false;
    this.layouts = 0;
  }

  read() {
    // Reading dirty geometry settles one modeled layout.
    if (this.dirty) {
      this.layouts += 1;
      this.dirty = false;
    }
    return 40;
  }

  write() {
    // Writing invalidates geometry until a read or frame flush settles it.
    this.dirty = true;
  }

  flush() {
    if (this.dirty) {
      this.layouts += 1;
      this.dirty = false;
    }
  }
}

function batchedLayouts() {
  const ledger = new Ledger();
  const heights = rows.map(() => ledger.read());
  rows.forEach((row, index) => {
    // The write phase only consumes the earlier geometry snapshot.
    void row;
    void heights[index];
    ledger.write();
  });
  ledger.flush();
  return ledger.layouts;
}

function interleavedLayouts() {
  const ledger = new Ledger();
  rows.forEach(() => {
    // Fault injection: every invalidating write is followed by a synchronous read.
    ledger.write();
    ledger.read();
  });
  ledger.flush();
  return ledger.layouts;
}

function fail(marker, detail) {
  console.error(marker + " " + detail);
  process.exit(1);
}

if (mode === "baseline") {
  const layouts = batchedLayouts();
  const listenerDelta = 0;
  const timerDelta = 0;
  const accessibleNames = rows.map((id) => "Open " + id);
  if (layouts !== 1 || listenerDelta !== 0 || timerDelta !== 0) {
    fail("LAB_BASELINE_INVALID", "resource or layout budget failed");
  }
  if (!accessibleNames.every((name) => name.startsWith("Open WO-"))) {
    fail("LAB_BASELINE_INVALID", "accessible name guard failed");
  }
  console.log("LAB_BASELINE_PASS layouts=1 listenerDelta=0 timerDelta=0");
} else if (mode === "layout") {
  const layouts = interleavedLayouts();
  if (layouts > 1) {
    fail("LAYOUT_THRASHING_FAULT", "layouts=" + layouts + " budget=1");
  }
} else if (mode === "listener") {
  // Fault injection: mount adds a listener and unmount omits its cleanup.
  const listenerDelta = 1;
  if (listenerDelta !== 0) {
    fail("LISTENER_LEAK_FAULT", "listenerDelta=" + listenerDelta);
  }
} else if (mode === "timer") {
  // Fault injection: a timer callback still owns the detached list token.
  const retainedPath = "timerCallback->oldListNode";
  if (retainedPath.includes("oldListNode")) {
    fail("TIMER_RETENTION_FAULT", "path=" + retainedPath);
  }
} else if (mode === "regression") {
  // Fault injection: visual optimization removed the button accessible names.
  const accessibleNames = rows.map(() => "");
  if (accessibleNames.some((name) => name.length === 0)) {
    fail("PERFORMANCE_REGRESSION_FAULT", "accessible-name-missing");
  }
} else {
  fail("UNKNOWN_LAB_MODE", mode);
}
