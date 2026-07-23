import unittest

from audit_workflow import audit


class WorkflowAuditTest(unittest.TestCase):
    def test_movable_action_tag_is_rejected(self) -> None:
        source = """permissions:\n  contents: read\nconcurrency:\n  group: ci\n  cancel-in-progress: true\njobs:\n  java-test:\n  web-test:\n  python-test:\n  release-gate:\n    needs: [java-test, web-test, python-test]\n    steps:\n      - uses: actions/checkout@v6\n"""
        self.assertTrue(any("not pinned" in item for item in audit(source)))


if __name__ == "__main__":
    unittest.main()
