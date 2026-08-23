import { normalizeNumericId } from "./.verify-dist/work-orders.js";

try {
  // This unchecked JavaScript boundary passes a string; emitted code has no number guard.
  normalizeNumericId("17");
  console.error("TYPE_ERASURE_CONTRAST_MISSING");
  process.exit(1);
} catch (error) {
  if (!(error instanceof TypeError)) {
    throw error;
  }
  console.log("TYPE_ERASURE_RUNTIME_CONTRAST=TypeError");
  console.log("TYPE_ERASURE_CONTRAST_PASS");
}
