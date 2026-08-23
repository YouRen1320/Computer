# Events and forms lab

Predict the baseline trace before running `./verify.sh`. The verifier checks one deterministic interaction contract and three isolated fault scripts:

- `DUPLICATE_EVENT_HANDLER`
- `DEFAULT_ACTION_LOSS`
- `EVENT_TARGET_CONFUSION`

Each fault must fail in its own process at the named marker. Repair one fault at a time, then rerun the same verifier. The simulator does not replace real-browser keyboard, navigation, Network, or accessibility evidence.
