import unittest

from postmortem import audit, corrective_actions


class PostmortemSolutionTest(unittest.TestCase):
    def test_actions_are_verifiable_and_owned(self) -> None:
        self.assertEqual([], audit(corrective_actions()))


if __name__ == "__main__":
    unittest.main()
