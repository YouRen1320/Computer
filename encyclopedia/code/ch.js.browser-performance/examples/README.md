# Browser performance example

This isolated example models a four-row work-order list. It compares interleaved geometry writes/reads with a read phase followed by a write phase, and checks that listener/timer ownership returns to zero.

Run:

    ./verify.sh

The layout ledger is deterministic control-flow evidence, not a browser renderer. A passing result does not prove Chrome Layout counts, long-task duration, compositor promotion, garbage collection, or heap reachability. Complete the chapter outcome by recording the same real interaction in the target browser and saving its Performance trace and heap evidence.
