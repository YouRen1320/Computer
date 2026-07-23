import unittest

from exercise import design


class ExerciseTest(unittest.TestCase):
    def test_design_uses_low_cardinality_user_slis_and_context_continuity(self) -> None:
        actual = design()
        self.assertNotIn("user_id", actual["labels"])
        self.assertEqual("threshold-good-event-ratio", actual["latency_measure"])
        self.assertEqual("slo-burn-rate", actual["alert_signal"])
        self.assertEqual(actual["incoming_trace_id"], actual["async_trace_id"])


if __name__ == "__main__":
    unittest.main()
