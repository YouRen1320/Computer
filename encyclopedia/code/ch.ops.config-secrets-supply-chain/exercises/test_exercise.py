import unittest

from exercise import release_allowed


class ExerciseTest(unittest.TestCase):
    def test_clean_risk_triage_may_release_even_with_documented_advisory(self) -> None:
        self.assertTrue(release_allowed({
            "cve_count": 1, "reachable_known_exploited": False,
            "unknown_config": [], "secret_marker_surfaces": [],
            "sbom_complete": True, "old_credential_valid": False,
            "new_credential_valid": True}))

    def test_marker_on_ci_log_must_block_without_recording_a_value(self) -> None:
        self.assertFalse(release_allowed({
            "cve_count": 0, "reachable_known_exploited": False,
            "unknown_config": [], "secret_marker_surfaces": ["ci-log"],
            "sbom_complete": True, "old_credential_valid": False,
            "new_credential_valid": True}))

    def test_every_hard_policy_failure_blocks(self) -> None:
        base = {
            "cve_count": 1, "reachable_known_exploited": False,
            "unknown_config": [], "secret_marker_surfaces": [],
            "sbom_complete": True, "old_credential_valid": False,
            "new_credential_valid": True,
        }
        for change in (
            {"unknown_config": ["profil"]},
            {"secret_marker_surfaces": ["ci-log"]},
            {"sbom_complete": False},
            {"old_credential_valid": True},
            {"new_credential_valid": False},
            {"reachable_known_exploited": True},
        ):
            with self.subTest(change=change):
                self.assertFalse(release_allowed({**base, **change}))


if __name__ == "__main__":
    unittest.main()
