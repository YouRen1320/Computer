import tempfile
import unittest
from pathlib import Path

from service_contract import validate


ROOT = Path(__file__).parent


class ServiceContractTest(unittest.TestCase):
    def test_fixture_satisfies_static_contract(self) -> None:
        self.assertEqual([], validate(ROOT / "factorycare-api.service", ROOT / "service-contract.json"))

    def test_root_service_is_rejected_at_the_first_policy_boundary(self) -> None:
        text = (ROOT / "factorycare-api.service").read_text(encoding="utf-8").replace(
            "User=factorycare", "User=root"
        )
        with tempfile.TemporaryDirectory() as directory:
            broken = Path(directory) / "broken.service"
            broken.write_text(text, encoding="utf-8")
            errors = validate(broken, ROOT / "service-contract.json")
        self.assertIn("Service.User must be a dedicated non-root account", errors)

    def test_relative_exec_start_is_rejected(self) -> None:
        text = (ROOT / "factorycare-api.service").read_text(encoding="utf-8").replace(
            "ExecStart=/opt/factorycare/api/bin/start", "ExecStart=bin/start"
        )
        with tempfile.TemporaryDirectory() as directory:
            broken = Path(directory) / "broken.service"
            broken.write_text(text, encoding="utf-8")
            errors = validate(broken, ROOT / "service-contract.json")
        self.assertIn("ExecStart executable must be an absolute path", errors)


if __name__ == "__main__":
    unittest.main()
