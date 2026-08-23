import json
import unittest

from observability import correlation_id, health, structured_log


class ObservabilityTest(unittest.TestCase):
    def test_valid_incoming_id_is_preserved(self) -> None:
        self.assertEqual("request-demo-0001",
                         correlation_id("request-demo-0001", lambda: "request-new-0002"))

    def test_log_is_machine_readable_and_rejects_sensitive_fields(self) -> None:
        record = json.loads(structured_log(
            service="java-api", event="work-order.loaded", level="INFO",
            correlation="request-demo-0001", attributes={"status": 200}))
        self.assertEqual("request-demo-0001", record["correlation_id"])
        with self.assertRaises(ValueError):
            structured_log(service="java-api", event="bad", level="INFO",
                           correlation="request-demo-0001", attributes={"authorization": "redacted"})

    def test_health_distinguishes_starting_critical_and_optional_failure(self) -> None:
        starting = health(process_ok=True, startup_complete=False, postgres_ok=False,
                          optional_provider_ok=True)
        self.assertTrue(starting["live"])
        self.assertFalse(starting["ready"])
        degraded = health(process_ok=True, startup_complete=True, postgres_ok=True,
                          optional_provider_ok=False)
        self.assertEqual("DEGRADED", degraded["state"])
        self.assertTrue(degraded["ready"])


if __name__ == "__main__":
    unittest.main()
