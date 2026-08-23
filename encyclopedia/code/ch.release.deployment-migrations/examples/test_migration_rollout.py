import unittest

from migration_rollout import (
    CanaryEvidence,
    ContractEvidence,
    SchemaFixture,
    application_rollback_supported,
    backfill_batch,
    canary_decision,
    contract,
    expand,
    read_v2,
    write_v1,
    write_v2,
)


class MigrationRolloutTest(unittest.TestCase):
    def test_expand_allows_v1_and_v2_to_coexist(self) -> None:
        schema = SchemaFixture()
        write_v1(schema, 1, "Alice")
        expand(schema)
        self.assertEqual("Alice", read_v2(schema, 1))
        write_v2(schema, 2, "Bob")
        self.assertEqual("Bob", schema.rows[2]["assignee_name"])
        self.assertTrue(application_rollback_supported(schema))

    def test_failed_backfill_resumes_from_last_verified_checkpoint(self) -> None:
        schema = SchemaFixture()
        for row_id in (1, 2, 3):
            write_v1(schema, row_id, f"user-{row_id}")
        expand(schema)
        checkpoint, complete = backfill_batch(schema, checkpoint=0, batch_size=3, fail_on_id=2)
        self.assertEqual((1, False), (checkpoint, complete))
        checkpoint, complete = backfill_batch(schema, checkpoint=checkpoint, batch_size=3)
        self.assertEqual((3, True), (checkpoint, complete))

    def test_bad_canary_rolls_back_before_traffic_promotion(self) -> None:
        evidence = CanaryEvidence("sha256:" + "a" * 64, 1, 1, 0.08, 120, "success")
        self.assertEqual("rollback:error-rate", canary_decision(evidence, max_error_rate=0.01, max_p95_ms=250))

    def test_contract_is_delayed_until_all_evidence_is_green(self) -> None:
        schema = SchemaFixture()
        write_v1(schema, 1, "Alice")
        expand(schema)
        backfill_batch(schema, checkpoint=0, batch_size=10)
        evidence = ContractEvidence(0, 0, True, True, True, True, "success")
        contract(schema, evidence)
        self.assertNotIn("assignee_name", schema.columns)
        self.assertFalse(application_rollback_supported(schema))


if __name__ == "__main__":
    unittest.main()
