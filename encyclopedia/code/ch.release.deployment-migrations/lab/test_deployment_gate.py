import unittest

from deployment_gate import GOOD_RECORD, audit


class DeploymentGateFaultTest(unittest.TestCase):
    def test_good_expand_stage_passes(self) -> None:
        self.assertEqual([], audit(dict(GOOD_RECORD)))

    def test_mixed_version_break_and_early_contract_are_detected(self) -> None:
        record = dict(GOOD_RECORD, old_app_contract="red", contract_started=True, backfill_complete=False)
        errors = audit(record)
        self.assertTrue(any("both app versions" in item for item in errors))
        self.assertTrue(any("contract began" in item for item in errors))

    def test_failed_migration_or_canary_cannot_receive_promoted_traffic(self) -> None:
        record = dict(GOOD_RECORD, migration_state="failed", canary_gate="red", traffic_promoted=True)
        errors = audit(record)
        self.assertTrue(any("migration" in item for item in errors))
        self.assertTrue(any("canary" in item for item in errors))

    def test_rollback_after_contract_and_unverified_forward_fix_are_detected(self) -> None:
        errors = audit(dict(GOOD_RECORD, rollback_to_old_app=True, legacy_schema_present=False, forward_fix_verified=False))
        self.assertTrue(any("cannot read" in item for item in errors))
        self.assertTrue(any("forward-fix" in item for item in errors))


if __name__ == "__main__":
    unittest.main()
