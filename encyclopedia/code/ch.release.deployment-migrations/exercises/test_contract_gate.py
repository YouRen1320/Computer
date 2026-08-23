import unittest

from contract_gate import contract_ready


class ContractGateExerciseTest(unittest.TestCase):
    def test_all_preconditions_green(self) -> None:
        self.assertTrue(contract_ready(backfill_complete=True, old_replica_count=0, legacy_read_count=0, canary_green=True))

    def test_old_replica_blocks_contract(self) -> None:
        self.assertFalse(contract_ready(backfill_complete=True, old_replica_count=1, legacy_read_count=0, canary_green=True))

    def test_legacy_reads_or_bad_canary_block_contract(self) -> None:
        self.assertFalse(contract_ready(backfill_complete=True, old_replica_count=0, legacy_read_count=2, canary_green=True))
        self.assertFalse(contract_ready(backfill_complete=True, old_replica_count=0, legacy_read_count=0, canary_green=False))


if __name__ == "__main__":
    unittest.main()
