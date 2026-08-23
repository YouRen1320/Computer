import unittest

from audit import audit


class AuditSolutionTest(unittest.TestCase):
    def test_latest_and_secret_context_are_rejected(self) -> None:
        errors = audit("FROM eclipse-temurin:latest\nUSER root\n", ["app.jar", ".env"])
        self.assertIn("base image must be pinned by digest", errors)
        self.assertIn("runtime user must be non-root", errors)
        self.assertIn("secret-like file entered build context: .env", errors)

    def test_pinned_non_root_source_passes(self) -> None:
        source = f"FROM runtime@sha256:{'f' * 64}\nUSER 10001:10001\n"
        self.assertEqual([], audit(source, ["app.jar"]))


if __name__ == "__main__":
    unittest.main()
