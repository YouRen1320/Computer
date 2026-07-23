from request import direct_request, langchain_request


def test_effective_requests_are_equal() -> None:
    assert langchain_request() == direct_request()
