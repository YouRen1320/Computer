"""Reference solution for the public Nginx source audit."""


def audit(config: str) -> list[str]:
    errors: list[str] = []
    if "set_real_ip_from 0.0.0.0/0" in config or "$http_x_forwarded_for" in config:
        errors.append("do not trust arbitrary forwarded client headers")
    api_start = config.find("location ^~ /api/")
    if api_start < 0:
        errors.append("API requires an isolated location without SPA fallback")
    if "fullchain.pem" not in config:
        errors.append("TLS requires a full certificate chain")
    if "max-age=31536000" in config and "location ^~ /assets/" not in config:
        errors.append("sensitive responses must not receive long-lived cache headers")
    return errors
