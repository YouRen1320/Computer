from routing import approval_route


def test_private_solution_routes_all_terminal_paths() -> None:
    assert approval_route("approve") == "execute"
    for decision in ("reject", "timeout", "cancel"):
        assert approval_route(decision) == "terminate"
