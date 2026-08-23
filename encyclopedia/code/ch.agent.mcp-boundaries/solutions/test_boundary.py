from boundary import backend_is_allowed


def test_private_solution_keeps_java_authority() -> None:
    assert backend_is_allowed("java_authoritative_api") is True
    assert backend_is_allowed("postgres_direct") is False
