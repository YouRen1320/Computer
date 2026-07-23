import unittest

from audit_fixture import audit


class AuditFixtureTest(unittest.TestCase):
    def test_secret_like_context_entry_is_rejected(self) -> None:
        digest = "a" * 64
        source = f"""FROM base@sha256:{digest} AS build
FROM runtime@sha256:{digest}
COPY --from=build /out/app /app
USER 10001
ENTRYPOINT [\"/app\"]
"""
        errors = audit(source, ["src/App.java", ".env"])
        self.assertIn("secret-like file entered build context: .env", errors)


if __name__ == "__main__":
    unittest.main()
