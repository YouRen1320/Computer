import unittest

from audit import audit


class ComposeExerciseTest(unittest.TestCase):
    def test_unsafe_topology_is_rejected(self) -> None:
        unsafe = {
            "services": {
                "db": {"image": "postgres:latest", "ports": ["5432:5432"], "restart": "always"},
                "api": {"image": "api:latest", "ports": ["8080:8080"],
                        "depends_on": {"db": {"condition": "service_started"}}, "restart": "always"},
                "proxy": {"image": "nginx:latest", "ports": ["80:80"], "restart": "always"},
            },
            "networks": {"default": {}},
            "volumes": {},
        }
        errors = audit(unsafe)
        self.assertIn("api must wait for a healthy db", errors)
        self.assertIn("db data must use a named volume", errors)
        self.assertIn("only proxy may publish a host port", errors)
        self.assertIn("data network must be isolated", errors)

    def test_safe_topology_has_no_findings(self) -> None:
        safe = {
            "services": {
                "db": {"volumes": [{"type": "volume", "source": "db-data"}]},
                "api": {"depends_on": {"db": {"condition": "service_healthy"}}},
                "proxy": {"ports": ["443:443"]},
            },
            "networks": {"data": {"internal": True}},
            "volumes": {"db-data": {}},
        }
        self.assertEqual([], audit(safe))


if __name__ == "__main__":
    unittest.main()
