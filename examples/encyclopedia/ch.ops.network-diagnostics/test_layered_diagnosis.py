import unittest

from layered_diagnosis import ProbeEvidence, earliest_failure


class LayeredDiagnosisTest(unittest.TestCase):
    def test_dns_failure_wins_over_downstream_unknowns(self) -> None:
        evidence = ProbeEvidence(False, False, False, None)
        self.assertEqual("dns", earliest_failure(evidence))

    def test_tls_is_only_diagnosed_after_tcp_succeeds(self) -> None:
        evidence = ProbeEvidence(True, True, False, None)
        self.assertEqual("tls", earliest_failure(evidence))

    def test_http_status_is_not_reported_as_tcp_failure(self) -> None:
        self.assertEqual("http-upstream", earliest_failure(ProbeEvidence(True, True, True, 502)))
        self.assertEqual("none", earliest_failure(ProbeEvidence(True, True, True, 204)))

    def test_proxy_selection_and_sni_hostname_have_explicit_evidence(self) -> None:
        intercepted = ProbeEvidence(True, False, False, None, proxy_selected=True, proxy_ok=False)
        self.assertEqual("proxy", earliest_failure(intercepted))
        hostname_mismatch = ProbeEvidence(True, True, True, None, tls_hostname_ok=False)
        self.assertEqual("tls-hostname", earliest_failure(hostname_mismatch))


if __name__ == "__main__":
    unittest.main()
