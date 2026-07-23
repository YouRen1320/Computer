import unittest

from incident_evidence import GOOD_RECORD, audit_incident


class IncidentEvidenceTest(unittest.TestCase):
    def test_complete_synthetic_record_passes(self) -> None:
        self.assertEqual([], audit_incident(GOOD_RECORD))

    def test_missing_evidence_and_action_owner_fail_closed(self) -> None:
        record = dict(GOOD_RECORD)
        record["timeline"] = [{"at": "2026-07-24T10:00:00Z", "kind": "declared", "evidence_ids": []}]
        record["corrective_actions"] = [dict(GOOD_RECORD["corrective_actions"][0], owner="")]
        errors = audit_incident(record)
        self.assertTrue(any("lacks evidence" in error for error in errors))
        self.assertTrue(any("three corrective" in error for error in errors))
        self.assertTrue(any("lacks owner" in error for error in errors))

    def test_real_verification_claim_is_rejected(self) -> None:
        record = dict(GOOD_RECORD, real_rto_rpo_verified=True)
        self.assertIn("example must not claim real RTO/RPO verification", audit_incident(record))


if __name__ == "__main__":
    unittest.main()
