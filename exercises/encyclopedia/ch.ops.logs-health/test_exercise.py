import unittest

from exercise import build_layer_records, probe


class ExerciseTest(unittest.TestCase):
    def test_same_id_is_propagated_and_sensitive_keys_are_absent(self) -> None:
        records = build_layer_records("request-demo-0001")
        self.assertEqual({"request-demo-0001"}, {item["correlation_id"] for item in records})
        self.assertTrue(all("sensitive_fields_logged" not in item for item in records))

    def test_database_failure_removes_readiness_but_keeps_liveness(self) -> None:
        self.assertEqual({"liveness_http": 200, "readiness_http": 503},
                         probe(process_ok=True, database_ok=False))


if __name__ == "__main__":
    unittest.main()
