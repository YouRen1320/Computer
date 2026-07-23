import tempfile
import unittest
from pathlib import Path

from validator import validate_unit


class ValidatorSolutionTest(unittest.TestCase):
    def test_root_service_is_rejected(self) -> None:
        unit = """[Service]\nUser=root\nExecStart=/opt/factorycare/start\nNoNewPrivileges=false\n"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "unsafe.service"
            path.write_text(unit, encoding="utf-8")
            errors = validate_unit(path)
        self.assertIn("User must be a dedicated non-root account", errors)
        self.assertIn("NoNewPrivileges=true is required", errors)

    def test_non_root_hardened_service_passes(self) -> None:
        unit = """[Service]\nUser=factorycare\nExecStart=/opt/factorycare/start\nNoNewPrivileges=true\n"""
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "safe.service"
            path.write_text(unit, encoding="utf-8")
            self.assertEqual([], validate_unit(path))


if __name__ == "__main__":
    unittest.main()
