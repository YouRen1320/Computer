import unittest

from release_manifest import same_artifact_in_every_environment, validate


class ReleaseManifestTest(unittest.TestCase):
    def test_complete_synthetic_manifest_passes(self) -> None:
        digest = "sha256:" + "a" * 64
        manifest = {
            "commit": "b" * 40,
            "artifacts": {"java-api": {"digest": digest, "sbom_digest": digest}},
            "quality_gates": {"java-test": "success", "security": "success"},
            "provenance_uri": "fixture://attestations/java-api",
        }
        self.assertEqual([], validate(manifest))

    def test_tag_is_not_an_immutable_identity(self) -> None:
        manifest = {
            "commit": "b" * 40,
            "artifacts": {"java-api": {"digest": "java-api:1.2", "sbom_digest": "missing"}},
            "quality_gates": {"java-test": "success"},
            "provenance_uri": "fixture://attestations/java-api",
        }
        self.assertTrue(any("digest" in error for error in validate(manifest)))

    def test_all_environments_must_resolve_to_one_digest(self) -> None:
        one = "sha256:" + "1" * 64
        two = "sha256:" + "2" * 64
        self.assertTrue(same_artifact_in_every_environment({"test": one, "production": one}))
        self.assertFalse(same_artifact_in_every_environment({"test": one, "production": two}))


if __name__ == "__main__":
    unittest.main()
