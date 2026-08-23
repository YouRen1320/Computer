import unittest

from audit_config import audit


class ComposePolicyTest(unittest.TestCase):
    def base(self) -> dict:
        digest = "image@sha256:" + "a" * 64
        return {
            "services": {
                "db": {"image": digest, "healthcheck": {}, "networks": {"data": None},
                       "volumes": [{"type": "volume", "source": "db-data", "target": "/var/lib/postgresql/data"}],
                       "restart": "unless-stopped"},
                "api": {"image": digest, "healthcheck": {}, "networks": {"data": None, "edge": None},
                        "depends_on": {"db": {"condition": "service_healthy"}}, "restart": "unless-stopped"},
                "proxy": {"image": digest, "networks": {"edge": None}, "ports": [{"target": 8443}],
                          "restart": "unless-stopped"},
                "toolbox": {"image": digest, "networks": {"data": None}, "profiles": ["debug"]},
            },
            "networks": {"data": {"internal": True}, "edge": {}},
        }

    def test_contract_passes(self) -> None:
        self.assertEqual([], audit(self.base()))

    def test_short_dependency_and_db_port_are_rejected(self) -> None:
        config = self.base()
        config["services"]["api"]["depends_on"]["db"]["condition"] = "service_started"
        config["services"]["db"]["ports"] = [{"target": 5432}]
        errors = audit(config)
        self.assertIn("api: db dependency must wait for service_healthy", errors)
        self.assertIn("db: only the edge proxy may publish a host port", errors)


if __name__ == "__main__":
    unittest.main()
