import unittest

from pipeline import JobResult, REQUIRED, release_decision


class PipelineTest(unittest.TestCase):
    def test_all_required_green_with_evidence_allows_release(self) -> None:
        results = [JobResult(name, "success", (f"{name}.xml",)) for name in REQUIRED]
        self.assertEqual((True, []), release_decision(results))

    def test_one_failed_test_blocks_release_but_keeps_failure_evidence(self) -> None:
        results = [JobResult(name, "success", (f"{name}.xml",)) for name in REQUIRED]
        results[1] = JobResult("web-test", "failure", ("playwright-report.zip",))
        allowed, reasons = release_decision(results)
        self.assertFalse(allowed)
        self.assertIn("required job did not succeed: web-test=failure", reasons)

    def test_missing_job_is_not_treated_as_success(self) -> None:
        allowed, reasons = release_decision([])
        self.assertFalse(allowed)
        self.assertIn("missing required job: java-test", reasons)


if __name__ == "__main__":
    unittest.main()
