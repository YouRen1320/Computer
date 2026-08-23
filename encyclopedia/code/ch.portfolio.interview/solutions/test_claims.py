import unittest

from claims import is_publishable


class PortfolioSolutionTest(unittest.TestCase):
    def test_truthful_project_claim_passes(self) -> None:
        claim = {
            "text": "Fault-tested a local FactoryCare tenant-isolation fixture",
            "evidence": ["fixture://tests/tenant"],
            "project_kind": "learning-project",
            "ownership": "reviewed AI draft and injected failures",
            "ai_assisted": True,
            "production": False,
            "verification_level": "verified-local",
        }
        self.assertTrue(is_publishable(claim))

    def test_false_dates_hidden_ownership_and_scope_escalation_fail(self) -> None:
        base = {"text": "A sufficiently long claim", "evidence": ["fixture://evidence"], "ownership": "shared"}
        self.assertFalse(is_publishable({**base, "project_kind": "employment", "verifiable_dates": False}))
        self.assertFalse(is_publishable({**base, "ai_assisted": True, "ownership": "independent"}))
        self.assertFalse(is_publishable({**base, "production": True, "verification_level": "verified-local"}))


if __name__ == "__main__":
    unittest.main()
