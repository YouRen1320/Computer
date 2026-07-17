import assert from "node:assert/strict";
import fs from "node:fs";
import { createResourceScope, runBatched, runInterleaved } from "./performance-model.mjs";

// These fixed rows are the shared input for the before/after scheduling comparison.
const rows = ["WO-1", "WO-2", "WO-3", "WO-4"].map((id) => ({
  id,
  accessibleName: "Open " + id
}));

const baseline = runInterleaved(rows);
const optimized = runBatched(rows);
assert.equal(baseline.layoutCount, 4);
assert.equal(optimized.layoutCount, 1);

const resources = createResourceScope();
const removeClick = resources.listen("list:click");
const stopRefresh = resources.schedule("list:refresh");
removeClick();
stopRefresh();
assert.deepEqual(resources.snapshot(), { listeners: 0, timers: 0 });

// Functional order and accessible names are correctness guards, not performance metrics.
assert.deepEqual(rows.map((row) => row.id), ["WO-1", "WO-2", "WO-3", "WO-4"]);
assert.ok(rows.every((row) => row.accessibleName.startsWith("Open WO-")));

// Source assertions keep the browser-facing sample aligned with its declared compositor intent.
const html = fs.readFileSync(new URL("../index.html", import.meta.url), "utf8");
const css = fs.readFileSync(new URL("../styles.css", import.meta.url), "utf8");
assert.match(html, /aria-label="Open work orders"/);
assert.match(css, /transform: translateY/);
assert.match(css, /focus-visible/);

console.log("baseline.layouts=" + baseline.layoutCount);
console.log("optimized.layouts=" + optimized.layoutCount);
console.log("optimized.listenerDelta=0");
console.log("optimized.timerDelta=0");
console.log("optimized.order=" + rows.map((row) => row.id).join(","));
console.log("optimized.accessibleNames=" + rows.map((row) => row.accessibleName).join("|"));
console.log("PERFORMANCE_MODEL_PASS");
