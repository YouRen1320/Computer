import unittest

from promotion import is_same_artifact


class PromotionExerciseTest(unittest.TestCase):
    def test_same_tag_with_different_digest_is_rejected(self) -> None:
        test = {"tag": "1.0", "digest": "sha256:" + "a" * 64}
        production = {"tag": "1.0", "digest": "sha256:" + "b" * 64}
        self.assertFalse(is_same_artifact(test, production))

    def test_different_tags_can_still_reference_same_digest(self) -> None:
        digest = "sha256:" + "a" * 64
        self.assertTrue(is_same_artifact({"tag": "candidate", "digest": digest}, {"tag": "stable", "digest": digest}))


if __name__ == "__main__":
    unittest.main()
