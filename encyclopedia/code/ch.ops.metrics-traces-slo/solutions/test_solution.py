import unittest

from solution import design


class SolutionTest(unittest.TestCase):
    def test_low_cardinality_user_sli_and_trace_contract(self) -> None:
        actual = design()
        self.assertEqual(["service", "route", "status_class"], actual["labels"])
        self.assertEqual("threshold-good-event-ratio", actual["latency_measure"])
        self.assertEqual("slo-burn-rate", actual["alert_signal"])
        self.assertEqual(actual["incoming_trace_id"], actual["async_trace_id"])


if __name__ == "__main__":
    unittest.main()
