import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from local_probe import probe


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802 - callback name is defined by stdlib
        redirects = {
            "/redirect": (301, "/health"),
            "/redirect-cross-host": (302, "https://other.example/health"),
            "/redirect-loop": (302, "/redirect-loop"),
            "/redirect-missing": (302, None),
        }
        if self.path in redirects:
            status, location = redirects[self.path]
            self.send_response(status)
            if location is not None:
                self.send_header("Location", location)
            self.end_headers()
            return
        status = 204 if self.path == "/health" else 503
        self.send_response(status)
        self.end_headers()

    def log_message(self, _format: str, *args: object) -> None:
        return


class LocalProbeTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls) -> None:
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=2)

    def test_local_health_path_proves_dns_tcp_and_http(self) -> None:
        results = probe("localhost", self.server.server_port)
        self.assertEqual(["dns", "tcp", "http"], [item.layer for item in results])
        self.assertTrue(all(item.ok for item in results))

    def test_http_failure_is_not_mislabelled_as_tcp(self) -> None:
        results = probe("localhost", self.server.server_port, "/broken")
        self.assertTrue(results[1].ok)
        self.assertEqual("http", results[2].layer)
        self.assertEqual("503", results[2].detail)

    def test_redirects_are_not_reported_as_healthy(self) -> None:
        expected = {
            "/redirect": "301:redirect",
            "/redirect-cross-host": "302:redirect-cross-host",
            "/redirect-loop": "302:redirect-loop",
            "/redirect-missing": "302:redirect-missing-location",
        }
        for path, detail in expected.items():
            with self.subTest(path=path):
                result = probe("localhost", self.server.server_port, path)[-1]
                self.assertFalse(result.ok)
                self.assertEqual(detail, result.detail)


if __name__ == "__main__":
    unittest.main()
