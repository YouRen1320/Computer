# Event loop exercise

The verifier is intentionally red. The starter oracle puts a zero-delay timer before two already queued microtasks.

Run `./verify.sh`, locate `ASYNC_ORDER_MISREAD_EXERCISE`, draw the queue registration order, then repair only the expected trace. Do not change delays or reorder the program to manufacture a pass.
