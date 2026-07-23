import unittest

from promotion import is_same_artifact


class PromotionSolutionTest(unittest.TestCase):
    def test_digest_not_tag_defines_identity(self) -> None:
        digest = "sha256:" + "a" * 64
        self.assertTrue(is_same_artifact({"tag": "candidate", "digest": digest}, {"tag": "stable", "digest": digest}))
        self.assertFalse(is_same_artifact({"tag": "1.0", "digest": digest}, {"tag": "1.0", "digest": "sha256:" + "b" * 64}))
        self.assertFalse(is_same_artifact({"tag": "1.0"}, {"tag": "1.0"}))


if __name__ == "__main__":
    unittest.main()
