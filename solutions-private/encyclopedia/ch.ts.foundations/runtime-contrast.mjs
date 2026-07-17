import { numericId } from "./.verify-dist/solution.js";

try {
  // JavaScript bypasses the erased annotation to prove that validation is a separate concern.
  numericId("17");
} catch (error) {
  if (error instanceof TypeError) {
    console.log("PRIVATE_TYPE_ERASURE_CONTRAST_PASS");
    process.exit(0);
  }
  throw error;
}

console.error("PRIVATE_TYPE_ERASURE_CONTRAST_MISSING");
process.exit(1);
