import unittest

from design_review import audit, design_packet


class DesignReviewExerciseTest(unittest.TestCase):
    def test_every_design_claim_is_traceable_and_reproducible(self) -> None:
        self.assertEqual([], audit(design_packet()))


if __name__ == "__main__":
    unittest.main()
