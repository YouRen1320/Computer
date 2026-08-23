"""Store that keeps one explicit embedding space."""


class VectorStore:
    def __init__(self, space_id: str, dimensions: int) -> None:
        self.space_id = space_id
        self.dimensions = dimensions
        self.rows: list[tuple[str, tuple[float, ...]]] = []

    def add(self, chunk_id: str, space_id: str, vector: tuple[float, ...]) -> None:
        if space_id != self.space_id:
            raise ValueError("embedding space mismatch")
        if len(vector) != self.dimensions:
            raise ValueError("dimension mismatch")
        self.rows.append((chunk_id, vector))
