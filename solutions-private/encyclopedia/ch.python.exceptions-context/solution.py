"""Private context-manager solution."""


class Resource:
    def __init__(self) -> None:
        self.closed = 0

    def __enter__(self) -> "Resource":
        return self

    def __exit__(self, exc_type, exc, traceback) -> bool:
        self.closed += 1
        return False
