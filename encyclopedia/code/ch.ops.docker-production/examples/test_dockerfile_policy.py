import unittest

from dockerfile_policy import audit, logical_lines


DIGEST = "1" * 64


class DockerfilePolicyTest(unittest.TestCase):
    def test_safe_two_stage_fixture_passes(self) -> None:
        dockerfile = f"""FROM eclipse-temurin:25-jdk@sha256:{DIGEST} AS build
RUN ./mvnw package
FROM eclipse-temurin:25-jre@sha256:{DIGEST}
COPY --from=build /src/app.jar /app/app.jar
USER 10001:10001
ENTRYPOINT [\"java\",\"-jar\",\"/app/app.jar\"]
"""
        self.assertEqual([], audit(dockerfile))

    def test_unpinned_root_shell_entrypoint_is_rejected(self) -> None:
        dockerfile = "FROM eclipse-temurin:latest\nUSER root\nENTRYPOINT java -jar app.jar\n"
        errors = audit(dockerfile)
        self.assertIn("a multi-stage build is required", errors)
        self.assertTrue(any("not pinned" in error for error in errors))
        self.assertIn("final runtime user must be non-root", errors)
        self.assertIn("ENTRYPOINT must use non-empty JSON exec form", errors)

    def test_continuations_form_one_instruction(self) -> None:
        source = "RUN one && " + "\\" + "\n  two\n"
        self.assertEqual(["RUN one && two"], logical_lines(source))


if __name__ == "__main__":
    unittest.main()
