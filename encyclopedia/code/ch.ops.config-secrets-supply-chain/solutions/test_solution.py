import unittest

from solution import release_allowed


BASE = {"cve_count": 1, "reachable_known_exploited": False,
        "unknown_config": [], "secret_marker_surfaces": [],
        "sbom_complete": True, "old_credential_valid": False,
        "new_credential_valid": True}


class SolutionTest(unittest.TestCase):
    def test_documented_unreachable_advisory_is_not_count_only_block(self) -> None:
        self.assertTrue(release_allowed(BASE))

    def test_every_hard_policy_failure_blocks(self) -> None:
        for change in ({"unknown_config": ["profil"]},
                       {"secret_marker_surfaces": ["ci-log"]},
                       {"sbom_complete": False},
                       {"old_credential_valid": True},
                       {"new_credential_valid": False},
                       {"reachable_known_exploited": True}):
            report = {**BASE, **change}
            with self.subTest(change=change):
                self.assertFalse(release_allowed(report))


if __name__ == "__main__":
    unittest.main()
