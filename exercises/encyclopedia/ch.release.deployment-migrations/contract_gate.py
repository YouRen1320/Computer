"""Public exercise: implement every contract precondition."""


def contract_ready(
    *,
    backfill_complete: bool,
    old_replica_count: int,
    legacy_read_count: int,
    canary_green: bool,
) -> bool:
    # Deliberately wrong: backfill alone cannot prove old readers are gone.
    return backfill_complete
