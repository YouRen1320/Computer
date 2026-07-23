import unittest
from dataclasses import replace

from backup_drill import RestoreTarget, create_test_envelope, factorycare_snapshot, restore_and_measure, utc


class BackupDrillExampleTest(unittest.TestCase):
    def setUp(self) -> None:
        self.key = b"fixture-key-outside-backup"
        self.envelope = create_test_envelope(
            factorycare_snapshot(),
            backup_id="backup-20260724-1200",
            cutoff=utc("2026-07-24T12:00:00"),
            key_id="kms://factorycare/backup-key/7",
            key=self.key,
            backup_location="object://backup-vault/factorycare",
            key_location="kms://security/factorycare",
        )

    def test_isolated_restore_meets_declared_objectives(self) -> None:
        result = restore_and_measure(
            self.envelope,
            key=self.key,
            target=RestoreTarget("restore-drill-20260724", "drill"),
            disaster_at=utc("2026-07-24T12:03:00"),
            restore_started_at=utc("2026-07-24T12:04:00"),
            restore_finished_at=utc("2026-07-24T12:09:00"),
            max_rpo_seconds=300,
            max_rto_seconds=600,
        )
        self.assertEqual(180, result.rpo_seconds)
        self.assertEqual(300, result.rto_seconds)
        self.assertEqual(2, result.row_counts["work_orders"])

    def test_tamper_and_production_target_fail_closed(self) -> None:
        corrupt = replace(self.envelope, ciphertext=self.envelope.ciphertext + b"!")
        with self.assertRaisesRegex(ValueError, "digest mismatch"):
            restore_and_measure(
                corrupt,
                key=self.key,
                target=RestoreTarget("bad", "drill"),
                disaster_at=utc("2026-07-24T12:03:00"),
                restore_started_at=utc("2026-07-24T12:04:00"),
                restore_finished_at=utc("2026-07-24T12:05:00"),
                max_rpo_seconds=300,
                max_rto_seconds=600,
            )

    def test_illegal_factorycare_transition_is_not_a_restorable_business_state(self) -> None:
        snapshot = factorycare_snapshot()
        snapshot["status_history"][4]["to_status"] = "CLOSED"
        snapshot["work_orders"][0]["status"] = "CLOSED"
        envelope = create_test_envelope(
            snapshot,
            backup_id="backup-illegal-transition",
            cutoff=utc("2026-07-24T12:00:00"),
            key_id="kms://factorycare/backup-key/7",
            key=self.key,
            backup_location="object://backup-vault/factorycare",
            key_location="kms://security/factorycare",
        )
        with self.assertRaisesRegex(ValueError, "illegal status transition"):
            restore_and_measure(
                envelope,
                key=self.key,
                target=RestoreTarget("illegal", "drill"),
                disaster_at=utc("2026-07-24T12:03:00"),
                restore_started_at=utc("2026-07-24T12:04:00"),
                restore_finished_at=utc("2026-07-24T12:05:00"),
                max_rpo_seconds=300,
                max_rto_seconds=600,
            )
        with self.assertRaisesRegex(ValueError, "never target production"):
            restore_and_measure(
                self.envelope,
                key=self.key,
                target=RestoreTarget("factorycare", "production"),
                disaster_at=utc("2026-07-24T12:03:00"),
                restore_started_at=utc("2026-07-24T12:04:00"),
                restore_finished_at=utc("2026-07-24T12:05:00"),
                max_rpo_seconds=300,
                max_rto_seconds=600,
            )


if __name__ == "__main__":
    unittest.main()
