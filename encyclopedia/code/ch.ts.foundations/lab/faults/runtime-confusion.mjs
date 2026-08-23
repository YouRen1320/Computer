import { normalizeNumericId } from "../.verify-dist/work-orders.js";

try {
  // Unchecked JavaScript supplies a string; TypeScript annotations are absent at runtime.
  normalizeNumericId("9");
} catch (error) {
  if (error instanceof TypeError) {
    console.error("TYPE_RUNTIME_CONFUSION_FAULT TypeError");
    process.exit(1);
  }
  throw error;
}

console.error("TYPE_RUNTIME_CONFUSION_FAULT expected runtime failure");
process.exit(1);
