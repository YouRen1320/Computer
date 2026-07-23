import unittest

from policy import PolicyError, audit_sbom, audit_surfaces, resolve_config, vulnerability_decision


class PolicyTest(unittest.TestCase):
    def test_precedence_and_unknown_key_rejection(self) -> None:
        actual = resolve_config(
            [("defaults", {"profile": "local", "log_level": "INFO"}),
             ("environment", {"profile": "production"})],
            allowed={"profile", "log_level"}, required={"profile", "log_level"})
        self.assertEqual("production", actual["profile"])
        with self.assertRaises(PolicyError):
            resolve_config([("environment", {"profil": "production"})],
                           allowed={"profile"}, required={"profile"})

    def test_secret_surfaces_use_boolean_reports(self) -> None:
        clean = [{"surface": value, "secret_marker_present": False}
                 for value in ("git-history", "image-layer", "ci-log")]
        self.assertEqual([], audit_surfaces(clean))
        self.assertEqual(["ci-log:secret-marker-present"], audit_surfaces([
            {"surface": "ci-log", "secret_marker_present": True}]))

    def test_sbom_is_reconciled_with_lock(self) -> None:
        sbom = {"components": [{"name": "java-api", "version": "1.0.0",
                 "purl": "pkg:maven/example/java-api@1.0.0", "hashes": ["sha256:fixture"]}]}
        self.assertEqual([], audit_sbom(sbom, {"java-api": "1.0.0"}))

    def test_vulnerability_is_triaged_not_counted(self) -> None:
        self.assertEqual("block-release", vulnerability_decision(
            {"reachable": True, "known_exploited": True, "severity": "HIGH"}))
        self.assertEqual("document-and-monitor", vulnerability_decision(
            {"reachable": False, "known_exploited": False, "severity": "CRITICAL"}))


if __name__ == "__main__":
    unittest.main()
