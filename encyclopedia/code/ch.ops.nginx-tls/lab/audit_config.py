"""Static Nginx/TLS source audit; it is not nginx -t or a TLS handshake."""

from __future__ import annotations

import json
from pathlib import Path
import re


ROOT = Path(__file__).resolve().parent


def block(text: str, marker: str) -> str:
    start = text.find(marker)
    if start < 0:
        return ""
    brace = text.find("{", start)
    if brace < 0:
        return ""
    depth = 0
    for index in range(brace, len(text)):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                return text[brace + 1:index]
    return ""


def audit(config: str, inventory: dict) -> list[str]:
    errors: list[str] = []
    api = block(config, "location ^~ /api/")
    assets = block(config, "location ^~ /assets/")
    index = block(config, "location = /index.html")
    spa = block(config, "location /")

    if not api:
        errors.append("API requires an explicit ^~ /api/ location")
    else:
        required = [
            "proxy_pass http://factorycare_api;",
            "proxy_set_header Host $host;",
            "proxy_set_header X-Forwarded-For $remote_addr;",
            "proxy_set_header X-Forwarded-Proto $scheme;",
            "proxy_connect_timeout",
            "proxy_send_timeout",
            "proxy_read_timeout",
            'Cache-Control "no-store"',
        ]
        for item in required:
            if item not in api:
                errors.append(f"API location missing contract: {item}")
        if "try_files" in api or "/index.html" in api:
            errors.append("API location must never use SPA fallback")

    trusted = re.findall(r"set_real_ip_from\s+([^;]+);", config)
    if not trusted or any(value.strip() in {"0.0.0.0/0", "::/0"} for value in trusted):
        errors.append("forwarded client IP requires explicit trusted proxy CIDRs")
    if "real_ip_recursive on;" not in config:
        errors.append("trusted proxy chain must be evaluated explicitly")

    if not re.search(r"ssl_certificate\s+\S*fullchain\.pem;", config):
        errors.append("TLS must reference the declared full certificate chain")
    if inventory.get("certificate_file") != "fullchain.pem":
        errors.append("certificate inventory must identify fullchain.pem")
    chain = inventory.get("chain_order", [])
    if len(chain) < 2 or not chain[0].startswith("leaf:") or not chain[1].startswith("intermediate:"):
        errors.append("certificate inventory must declare leaf before intermediate")
    if inventory.get("hostname") != "factorycare.example.test":
        errors.append("certificate inventory hostname does not match server_name")

    if not assets or "immutable" not in assets or "try_files $uri =404;" not in assets:
        errors.append("versioned assets require immutable caching and no SPA fallback")
    if not index or "no-cache" not in index:
        errors.append("index.html must be revalidated")
    if not spa or "try_files $uri $uri/ /index.html;" not in spa:
        errors.append("SPA route fallback is missing from the non-API location")
    return errors


def main() -> None:
    source = (ROOT / "nginx.fixture.conf").read_text(encoding="utf-8")
    inventory = json.loads((ROOT / "tls-inventory.fixture.json").read_text(encoding="utf-8"))
    errors = audit(source, inventory)
    if errors:
        raise SystemExit("\n".join(errors))
    print("PASS static Nginx route/header/cache/TLS-inventory source contracts")
    print("UNVERIFIED nginx -t, certificate cryptography/hostname/chain, live handshake, proxy headers and upstream timeouts")


if __name__ == "__main__":
    main()
