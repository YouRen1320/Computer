import unittest

from verify_manifest import verify


class PromotionManifestTest(unittest.TestCase):
    def test_environment_rebuild_is_rejected(self) -> None:
        digest = "sha256:" + "a" * 64
        data = {
            "commit": "b" * 40,
            "quality_gates": {"ci": "success"},
            "artifacts": {"api": {"digest": digest, "sbom_digest": digest, "provenance_uri": "fixture://p"}},
            "environments": {"test": {"api": digest}, "production": {"api": "sha256:" + "c" * 64}},
            "smoke": {"tls": "pass", "static": "pass", "api": "pass", "reported_commit": "b" * 40},
        }
        self.assertIn("production resolved a different api artifact", verify(data))


if __name__ == "__main__":
    unittest.main()
