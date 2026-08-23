import unittest

from audit_config import audit


INVENTORY = {
    "hostname": "factorycare.example.test",
    "certificate_file": "fullchain.pem",
    "chain_order": ["leaf:factorycare.example.test", "intermediate:fixture-ca"],
}


class NginxPolicyTest(unittest.TestCase):
    def safe(self) -> str:
        return """
set_real_ip_from 172.16.0.0/12;
real_ip_recursive on;
ssl_certificate /tls/fullchain.pem;
location ^~ /api/ {
 proxy_pass http://factorycare_api;
 proxy_set_header Host $host;
 proxy_set_header X-Forwarded-For $remote_addr;
 proxy_set_header X-Forwarded-Proto $scheme;
 proxy_connect_timeout 3s;
 proxy_send_timeout 30s;
 proxy_read_timeout 30s;
 add_header Cache-Control "no-store" always;
}
location ^~ /assets/ {
 try_files $uri =404;
 add_header Cache-Control "public, max-age=31536000, immutable" always;
}
location = /index.html { add_header Cache-Control "no-cache" always; }
location / { try_files $uri $uri/ /index.html; }
"""

    def test_safe_source_contract_passes(self) -> None:
        self.assertEqual([], audit(self.safe(), INVENTORY))

    def test_spoofable_header_and_api_fallback_are_rejected(self) -> None:
        source = self.safe().replace("172.16.0.0/12", "0.0.0.0/0").replace(
            "proxy_pass http://factorycare_api;", "proxy_pass http://factorycare_api; try_files $uri /index.html;"
        )
        errors = audit(source, INVENTORY)
        self.assertIn("forwarded client IP requires explicit trusted proxy CIDRs", errors)
        self.assertIn("API location must never use SPA fallback", errors)


if __name__ == "__main__":
    unittest.main()
