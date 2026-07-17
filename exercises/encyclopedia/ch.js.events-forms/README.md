# Events and forms exercise

The verifier is intentionally red. A nested `<span>` click is delegated from the list root, but the starter maps identity from the wrong event property.

Run `./verify.sh`, predict the first trustworthy difference, and repair `resolveCommand` without binding a listener to every button. Success means the same nested click yields exactly `assign:WO-2`; do not remove the marker check or hard-code the answer in the runner.
