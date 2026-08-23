import unittest

from gate import may_release


class GateSolutionTest(unittest.TestCase):
    def test_all_required_green_allows_release(self) -> None:
        self.assertTrue(may_release({"java": "success", "web": "success"}, {"java", "web"}))

    def test_failure_missing_and_empty_requirements_block(self) -> None:
        self.assertFalse(may_release({"java": "success", "web": "failure"}, {"java", "web"}))
        self.assertFalse(may_release({"java": "success"}, {"java", "web"}))
        self.assertFalse(may_release({}, set()))


if __name__ == "__main__":
    unittest.main()
