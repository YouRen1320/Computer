"""Reference fail-closed contract gate."""


def contract_ready(
    *,
    backfill_complete: bool,
    old_replica_count: int,
    legacy_read_count: int,
    canary_green: bool,
) -> bool:
    return backfill_complete and old_replica_count == 0 and legacy_read_count == 0 and canary_green
