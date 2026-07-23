import unittest

from diagnose import earliest_failed_layer


class DiagnoseExerciseTest(unittest.TestCase):
    def test_dns_is_first_when_every_downstream_probe_also_fails(self) -> None:
        probes = {"dns": False, "tcp": False, "tls": False, "http": False}
        self.assertEqual("dns", earliest_failed_layer(probes))


if __name__ == "__main__":
    unittest.main()
