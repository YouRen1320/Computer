import unittest

from gate import is_releasable


class AcceptanceExerciseTest(unittest.TestCase):
    def test_cross_tenant_leak_blocks_release_despite_200s(self) -> None:
        report = {"http_statuses": [200, 200], "cross_tenant_leaks": 1, "rollback": "pass"}
        self.assertFalse(is_releasable(report))

    def test_ai_block_and_missing_restore_block_release(self) -> None:
        report = {"http_statuses": [200], "cross_tenant_leaks": 0, "ai_core_flow": "blocked", "restore": "missing"}
        self.assertFalse(is_releasable(report))


if __name__ == "__main__":
    unittest.main()
