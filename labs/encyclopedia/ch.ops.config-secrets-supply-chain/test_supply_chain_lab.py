import unittest
from pathlib import Path

from supply_chain_lab import evaluate, load_fixture


class SupplyChainLabTest(unittest.TestCase):
    def setUp(self) -> None:
        self.data = load_fixture(Path(__file__).with_name("release-fixture.json"))

    def test_full_oracle(self) -> None:
        result = evaluate(self.data)
        self.assertTrue(result["verified"])
        self.assertEqual([], result["surface_findings"])
        self.assertEqual("v7", result["secret_reference"]["version"])

    def test_leak_report_blocks_the_oracle_without_a_secret_value(self) -> None:
        self.data["surface_reports"][1]["secret_marker_present"] = True
        result = evaluate(self.data)
        self.assertFalse(result["verified"])
        self.assertEqual(["image-layer"], result["surface_findings"])

    def test_unknown_config_and_sbom_drift_are_visible(self) -> None:
        self.data["config"]["environment"]["profil"] = "typo"
        self.data["sbom"]["components"][0]["version"] = "1.0.1"
        result = evaluate(self.data)
        self.assertFalse(result["checks"]["config_schema"])
        self.assertFalse(result["checks"]["sbom_matches_lock"])

    def test_rotation_requires_old_invalid_and_new_valid(self) -> None:
        self.data["rotation"]["old_valid_after_cutover"] = True
        self.assertFalse(evaluate(self.data)["checks"]["rotation_cutover"])


if __name__ == "__main__":
    unittest.main()
