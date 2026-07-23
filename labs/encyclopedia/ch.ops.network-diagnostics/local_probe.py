"""Small local-only DNS/TCP/HTTP probe; it never contacts the public network."""

from __future__ import annotations

import http.client
import socket
from dataclasses import dataclass


@dataclass(frozen=True)
class Result:
    layer: str
    ok: bool
    detail: str


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
        results.append(Result("http", 200 <= response.status < 400, str(response.status)))
    except OSError as error:
        results.append(Result("http", False, error.__class__.__name__))
    finally:
        connection.close()
    return results
