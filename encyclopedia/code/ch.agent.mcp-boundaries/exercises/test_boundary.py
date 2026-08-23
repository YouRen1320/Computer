from boundary import backend_is_allowed


def test_only_authoritative_java_api_is_allowed() -> None:
    assert backend_is_allowed("java_authoritative_api") is True
    assert backend_is_allowed("postgres_direct") is False
