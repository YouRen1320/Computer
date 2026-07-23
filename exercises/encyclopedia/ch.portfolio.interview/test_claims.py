import unittest

from claims import is_publishable


class PortfolioExerciseTest(unittest.TestCase):
    def test_unverifiable_three_year_employment_claim_is_rejected(self) -> None:
        claim = {"text": "Owned FactoryCare in production for three years", "evidence": [], "verifiable_dates": False}
        self.assertFalse(is_publishable(claim))

    def test_ai_and_team_work_cannot_be_claimed_as_independent(self) -> None:
        claim = {"text": "Independently designed and implemented the entire platform", "ai_assisted": True, "team": True}
        self.assertFalse(is_publishable(claim))


if __name__ == "__main__":
    unittest.main()
