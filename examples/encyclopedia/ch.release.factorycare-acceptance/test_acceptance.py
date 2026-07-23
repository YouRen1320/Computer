import unittest

from acceptance import validate_release


def valid_report() -> dict:
    digest = "sha256:" + "a" * 64
    return {
        "api_contract": "factorycare-v1",
        "artifacts": {"java-api": digest, "web": "sha256:" + "b" * 64},
        "clients": {
            "web": {"contract": "factorycare-v1", "result": "pass"},
            "miniapp": {"contract": "factorycare-v1", "result": "pass"},
            "flutter": {"contract": "factorycare-v1", "result": "pass"},
        },
        "cross_tenant_leaks": 0,
        "ai_unavailable": {"core_work_order_flow": "pass"},
        "rollback": {"result": "pass"},
        "restore": {"result": "pass"},
    }


class AcceptanceContractTest(unittest.TestCase):
    def test_complete_synthetic_report_passes(self) -> None:
        self.assertEqual([], validate_release(valid_report()))

    def test_mutable_tag_and_tenant_leak_fail_closed(self) -> None:
        report = valid_report()
        report["artifacts"]["java-api"] = "factorycare-api:latest"
        report["cross_tenant_leaks"] = 1
        errors = validate_release(report)
        self.assertTrue(any("immutable" in error for error in errors))
        self.assertTrue(any("cross-tenant" in error for error in errors))

    def test_ai_outage_cannot_block_core_business(self) -> None:
        report = valid_report()
        report["ai_unavailable"]["core_work_order_flow"] = "blocked"
        self.assertTrue(any("AI" in error for error in validate_release(report)))


if __name__ == "__main__":
    unittest.main()
