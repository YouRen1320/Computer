export class LayoutLedger {
  #dirty = false;

  constructor() {
    // The ledger records scheduling intent; it does not simulate a browser rendering engine.
    this.layoutCount = 0;
    this.operations = [];
  }

  readGeometry(rowId) {
    // A read after an invalidating write represents a synchronous layout settlement.
    if (this.#dirty) {
      this.layoutCount += 1;
      this.#dirty = false;
    }
    this.operations.push("read:" + rowId);
    return 40;
  }

  writeLayoutStyle(rowId, offset) {
    // A geometry-affecting style write invalidates the modeled layout until settlement.
    this.#dirty = true;
    this.operations.push("write:" + rowId + ":" + offset);
  }

  flushFrame() {
    // The frame boundary coalesces all still-pending writes into one modeled layout unit.
    if (this.#dirty) {
      this.layoutCount += 1;
      this.#dirty = false;
    }
  }
}

export function runInterleaved(rows) {
  const ledger = new LayoutLedger();
  rows.forEach((row, index) => {
    // This deliberately alternates write/read to provide the before baseline.
    ledger.writeLayoutStyle(row.id, index * 40);
    ledger.readGeometry(row.id);
  });
  ledger.flushFrame();
  return ledger;
}

export function runBatched(rows) {
  const ledger = new LayoutLedger();
  // Geometry is snapshotted before any write invalidates the modeled frame.
  const heights = rows.map((row) => ledger.readGeometry(row.id));
  rows.forEach((row, index) => {
    ledger.writeLayoutStyle(row.id, heights[index] * index);
  });
  ledger.flushFrame();
  return ledger;
}

export function createResourceScope() {
  const listeners = new Set();
  const timers = new Set();

  return {
    listen(key) {
      // Registration returns the exact cleanup owner for this listener key.
      listeners.add(key);
      return () => listeners.delete(key);
    },
    schedule(key) {
      // The timer token models callback ownership, not elapsed wall-clock time.
      timers.add(key);
      return () => timers.delete(key);
    },
    snapshot() {
      return { listeners: listeners.size, timers: timers.size };
    }
  };
}
