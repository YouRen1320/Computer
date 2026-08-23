import unittest

from diagnose import earliest_failed_layer


class DiagnoseSolutionTest(unittest.TestCase):
    def test_each_layer_has_a_distinct_first_failure(self) -> None:
        self.assertEqual("dns", earliest_failed_layer({"dns": False, "tcp": False, "tls": False, "http": False}))
        self.assertEqual("tcp", earliest_failed_layer({"dns": True, "tcp": False, "tls": False, "http": False}))
        self.assertEqual("tls", earliest_failed_layer({"dns": True, "tcp": True, "tls": False, "http": False}))
        self.assertEqual("http", earliest_failed_layer({"dns": True, "tcp": True, "tls": True, "http": False}))
        self.assertEqual("none", earliest_failed_layer({"dns": True, "tcp": True, "tls": True, "http": True}))


if __name__ == "__main__":
    unittest.main()
