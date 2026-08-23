import unittest

from restore_policy import restore_allowed


class RestorePolicySolutionTest(unittest.TestCase):
    def test_all_controls_are_required(self) -> None:
        self.assertTrue(restore_allowed(environment="drill", target_empty=True, key_separated=True))
        self.assertFalse(restore_allowed(environment="production", target_empty=True, key_separated=True))
        self.assertFalse(restore_allowed(environment="drill", target_empty=False, key_separated=True))
        self.assertFalse(restore_allowed(environment="drill", target_empty=True, key_separated=False))


if __name__ == "__main__":
    unittest.main()
