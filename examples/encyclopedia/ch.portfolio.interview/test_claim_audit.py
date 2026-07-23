import unittest

from claim_audit import audit_claim


class ClaimAuditTest(unittest.TestCase):
    def test_truthful_local_project_claim_passes(self) -> None:
        claim = {
            "text": "Implemented and fault-tested a tenant-aware work-order API fixture",
            "project_kind": "learning-project",
            "ownership": "defined invariants, reviewed AI draft, wrote failure tests",
            "evidence": ["fixture://commit/abc", "fixture://reports/tests"],
            "verification_level": "verified-local",
            "ai_assisted": True,
            "human_verification": "fixture://reviews/1",
            "production": False,
        }
        self.assertEqual([], audit_claim(claim))

    def test_fake_employment_dates_and_local_to_production_escalation_fail(self) -> None:
        claim = {
            "text": "Three years of production ownership",
            "project_kind": "employment",
            "ownership": "independent",
            "evidence": ["fixture://local-test"],
            "verification_level": "verified-local",
            "production": True,
        }
        errors = audit_claim(claim)
        self.assertTrue(any("dates" in item for item in errors))
        self.assertTrue(any("production" in item for item in errors))


if __name__ == "__main__":
    unittest.main()
