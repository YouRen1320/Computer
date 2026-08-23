import unittest

from gate import may_release


class GateExerciseTest(unittest.TestCase):
    def test_one_failure_blocks_release(self) -> None:
        results = {"java": "success", "web": "failure", "python": "success"}
        self.assertFalse(may_release(results, {"java", "web", "python"}))

    def test_missing_required_job_blocks_release(self) -> None:
        self.assertFalse(may_release({"java": "success"}, {"java", "web"}))


if __name__ == "__main__":
    unittest.main()
