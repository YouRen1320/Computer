import unittest

from restore_policy import restore_allowed


class RestorePolicyExerciseTest(unittest.TestCase):
    def test_isolated_empty_target_with_external_key_is_allowed(self) -> None:
        self.assertTrue(restore_allowed(environment="drill", target_empty=True, key_separated=True))

    def test_production_is_never_a_drill_target(self) -> None:
        self.assertFalse(restore_allowed(environment="production", target_empty=True, key_separated=True))

    def test_colocated_key_is_rejected(self) -> None:
        self.assertFalse(restore_allowed(environment="drill", target_empty=True, key_separated=False))


if __name__ == "__main__":
    unittest.main()
