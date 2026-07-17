# TypeScript foundations diagnostic lab

The green verifier proves the strict baseline, then requires the following injected faults to fail for their intended reason:

- SHAPE_FAULT
- FUNCTION_SIGNATURE_FAULT
- UNSAFE_OPTIONAL_ACCESS_FAULT
- TYPE_RUNTIME_CONFUSION_FAULT

Run:

    ./verify.sh

The type fixtures are outside the baseline tsconfig include set so a valid project can stay green while each negative compiler oracle is checked independently.
