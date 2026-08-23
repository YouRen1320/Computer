"""Small local-only DNS/TCP/HTTP probe; it never contacts the public network."""

from __future__ import annotations

import http.client
import socket
from dataclasses import dataclass
from urllib.parse import urlsplit


@dataclass(frozen=True)
class Result:
    layer: str
    ok: bool
    detail: str


def _http_detail(status: int, location: str | None, *, host: str, path: str) -> str:
    """Classify redirects without copying an arbitrary Location value into evidence."""
    if not 300 <= status < 400:
        return str(status)
    if not location:
        return f"{status}:redirect-missing-location"
    target = urlsplit(location)
    if target.hostname and target.hostname != host:
        return f"{status}:redirect-cross-host"
    target_path = target.path or path
    if target_path == path:
        return f"{status}:redirect-loop"
    return f"{status}:redirect"


def probe(host: str, port: int, path: str = "/health", timeout: float = 1.0) -> list[Result]:
    results: list[Result] = []
    try:
        addresses = socket.getaddrinfo(host, port, type=socket.SOCK_STREAM)
    except socket.gaierror as error:
        return [Result("dns", False, error.__class__.__name__)]
    results.append(Result("dns", True, addresses[0][4][0]))

    try:
        with socket.create_connection((host, port), timeout=timeout):
            pass
    except OSError as error:
        results.append(Result("tcp", False, error.__class__.__name__))
        return results
    results.append(Result("tcp", True, "connected"))

    connection = http.client.HTTPConnection(host, port, timeout=timeout)
    try:
        connection.request("GET", path)
        response = connection.getresponse()
        response.read()
        # A health contract accepts only 2xx. Redirects are a separate failure
        # class because login, host and proxy loops must not look healthy.
        detail = _http_detail(
            response.status,
            response.getheader("Location"),
            host=host,
            path=path,
        )
        results.append(Result("http", 200 <= response.status < 300, detail))
    except OSError as error:
        results.append(Result("http", False, error.__class__.__name__))
    finally:
        connection.close()
    return results
