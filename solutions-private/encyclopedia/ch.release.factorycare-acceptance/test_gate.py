import unittest

from gate import is_releasable


class AcceptanceSolutionTest(unittest.TestCase):
    def test_all_critical_evidence_is_required(self) -> None:
        good = {
            "http_statuses": [200, 200],
            "cross_tenant_leaks": 0,
            "ai_core_flow": "pass",
            "rollback": "pass",
            "restore": "pass",
        }
        self.assertTrue(is_releasable(good))
        for field, value in (("cross_tenant_leaks", 1), ("ai_core_flow", "blocked"), ("rollback", "missing"), ("restore", "missing")):
            broken = dict(good)
            broken[field] = value
            self.assertFalse(is_releasable(broken), field)


if __name__ == "__main__":
    unittest.main()
