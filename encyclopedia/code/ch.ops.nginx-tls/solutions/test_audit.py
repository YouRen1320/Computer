import unittest

from audit import audit


class NginxExerciseTest(unittest.TestCase):
    def test_spoofing_fallback_chain_and_cache_faults_are_rejected(self) -> None:
        unsafe = """
set_real_ip_from 0.0.0.0/0;
ssl_certificate /tls/cert.pem;
location / {
  try_files $uri /index.html;
  proxy_set_header X-Forwarded-For $http_x_forwarded_for;
  add_header Cache-Control "public, max-age=31536000";
}
"""
        errors = audit(unsafe)
        self.assertIn("do not trust arbitrary forwarded client headers", errors)
        self.assertIn("API requires an isolated location without SPA fallback", errors)
        self.assertIn("TLS requires a full certificate chain", errors)
        self.assertIn("sensitive responses must not receive long-lived cache headers", errors)

    def test_scoped_safe_source_passes(self) -> None:
        safe = """
set_real_ip_from 10.0.0.0/8;
ssl_certificate /tls/fullchain.pem;
location ^~ /api/ { proxy_pass http://java-api; }
location ^~ /assets/ { add_header Cache-Control "public, max-age=31536000"; }
location / { try_files $uri /index.html; }
"""
        self.assertEqual([], audit(safe))


if __name__ == "__main__":
    unittest.main()
