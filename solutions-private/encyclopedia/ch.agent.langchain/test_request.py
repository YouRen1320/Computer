from request import direct_request, langchain_request


def test_private_solution_keeps_request_parity() -> None:
    assert langchain_request() == direct_request()
