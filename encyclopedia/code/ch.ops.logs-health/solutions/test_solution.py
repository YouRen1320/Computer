import unittest

from solution import build_layer_records, probe


class SolutionTest(unittest.TestCase):
    def test_correlation_id_is_unchanged(self) -> None:
        records = build_layer_records("request-demo-0001")
        self.assertEqual({"request-demo-0001"}, {item["correlation_id"] for item in records})
        self.assertTrue(all("sensitive_fields_logged" not in item for item in records))

    def test_probe_matrix(self) -> None:
        self.assertEqual({"liveness_http": 200, "readiness_http": 503}, probe(True, False))
        self.assertEqual({"liveness_http": 503, "readiness_http": 503}, probe(False, True))
        self.assertEqual({"liveness_http": 200, "readiness_http": 200}, probe(True, True))
        self.assertEqual({"liveness_http": 503, "readiness_http": 503}, probe(False, False))


if __name__ == "__main__":
    unittest.main()
