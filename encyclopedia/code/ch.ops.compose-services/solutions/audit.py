"""Reference solution for the public Compose policy exercise."""


def audit(config: dict) -> list[str]:
    errors: list[str] = []
    services = config.get("services", {})
    db, api = services.get("db", {}), services.get("api", {})
    dependency = api.get("depends_on", {}).get("db", {})
    if dependency.get("condition") != "service_healthy":
        errors.append("api must wait for a healthy db")
    mounts = db.get("volumes", [])
    if not any(isinstance(item, dict) and item.get("type") == "volume" for item in mounts):
        errors.append("db data must use a named volume")
    if any(service.get("ports") for name, service in services.items() if name != "proxy"):
        errors.append("only proxy may publish a host port")
    if not config.get("networks", {}).get("data", {}).get("internal", False):
        errors.append("data network must be isolated")
    return errors
