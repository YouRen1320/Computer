import unittest

from audit import audit


class AuditExerciseTest(unittest.TestCase):
    def test_latest_and_secret_context_are_rejected(self) -> None:
        errors = audit("FROM eclipse-temurin:latest\nUSER root\n", ["app.jar", ".env"])
        self.assertIn("base image must be pinned by digest", errors)
        self.assertIn("runtime user must be non-root", errors)
        self.assertIn("secret-like file entered build context: .env", errors)


if __name__ == "__main__":
    unittest.main()
