from routing import approval_route


def test_only_approval_can_reach_execute() -> None:
    assert approval_route("approve") == "execute"
    assert approval_route("reject") == "terminate"
    assert approval_route("timeout") == "terminate"
    assert approval_route("cancel") == "terminate"
