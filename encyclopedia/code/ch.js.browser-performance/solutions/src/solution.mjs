import assert from "node:assert/strict";

class PerformanceSession {
  constructor() {
    // The session owns modeled geometry, listener, and timer state for one list mount.
    this.geometryDirty = false;
    this.layouts = 0;
    this.listeners = new Set();
    this.timers = new Set();
  }

  readGeometry() {
    if (this.geometryDirty) {
      this.layouts += 1;
      this.geometryDirty = false;
    }
    return 40;
  }

  writeLayoutStyle() {
    // The model invalidates geometry here; compositor-only transform evidence needs a browser trace.
    this.geometryDirty = true;
  }

  flushFrame() {
    if (this.geometryDirty) {
      this.layouts += 1;
      this.geometryDirty = false;
    }
  }

  listen(key) {
    // Returning cleanup binds removal to the exact registration token.
    this.listeners.add(key);
    return () => this.listeners.delete(key);
  }

  schedule(key) {
    // The token represents a future callback retaining session state.
    this.timers.add(key);
    return () => this.timers.delete(key);
  }
}

const rows = ["WO-1", "WO-2", "WO-3", "WO-4"].map((id) => ({
  id,
  accessibleName: "Open " + id
}));
const session = new PerformanceSession();

// The read snapshot is the only geometry data source used during the write phase.
const heights = rows.map(() => session.readGeometry());
rows.forEach((row, index) => {
  void row;
  void heights[index];
  session.writeLayoutStyle();
});
session.flushFrame();

const removeClick = session.listen("list:click");
const stopRefresh = session.schedule("list:refresh");
removeClick();
stopRefresh();

assert.equal(session.layouts, 1);
assert.equal(session.listeners.size, 0);
assert.equal(session.timers.size, 0);
assert.deepEqual(rows.map((row) => row.id), ["WO-1", "WO-2", "WO-3", "WO-4"]);
assert.ok(rows.every((row) => row.accessibleName.startsWith("Open WO-")));

console.log("PRIVATE_PERFORMANCE_SOLUTION_PASS layouts=1 listenerDelta=0 timerDelta=0");
