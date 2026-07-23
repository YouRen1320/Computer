import unittest

from restore_drill import GOOD_RECORD, audit


class RestoreDrillFaultTest(unittest.TestCase):
    def test_good_record_passes(self) -> None:
        self.assertEqual([], audit(dict(GOOD_RECORD)))

    def test_exit_code_only_and_colocated_key_are_detected(self) -> None:
        record = dict(GOOD_RECORD, manifest_verified=False, key_failure_domain="object-vault-a")
        errors = audit(record)
        self.assertTrue(any("exit code alone" in item for item in errors))
        self.assertTrue(any("failure domain" in item for item in errors))

    def test_production_restore_and_mid_transaction_snapshot_are_detected(self) -> None:
        record = dict(GOOD_RECORD, target_environment="production", transaction_consistent=False)
        errors = audit(record)
        self.assertTrue(any("production" in item for item in errors))
        self.assertTrue(any("mid-state" in item for item in errors))

    def test_business_oracle_and_objectives_are_required(self) -> None:
        record = dict(
            GOOD_RECORD,
            business_invariants_passed=False,
            restored_row_hash="sha256:wrong",
            rpo_seconds=301,
            rto_seconds=601,
        )
        errors = audit(record)
        self.assertEqual(4, len(errors))


if __name__ == "__main__":
    unittest.main()
