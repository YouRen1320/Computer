import unittest

from contract_gate import contract_ready


class ContractGateSolutionTest(unittest.TestCase):
    def test_each_condition_is_required(self) -> None:
        self.assertTrue(contract_ready(backfill_complete=True, old_replica_count=0, legacy_read_count=0, canary_green=True))
        self.assertFalse(contract_ready(backfill_complete=False, old_replica_count=0, legacy_read_count=0, canary_green=True))
        self.assertFalse(contract_ready(backfill_complete=True, old_replica_count=1, legacy_read_count=0, canary_green=True))
        self.assertFalse(contract_ready(backfill_complete=True, old_replica_count=0, legacy_read_count=1, canary_green=True))
        self.assertFalse(contract_ready(backfill_complete=True, old_replica_count=0, legacy_read_count=0, canary_green=False))


if __name__ == "__main__":
    unittest.main()
