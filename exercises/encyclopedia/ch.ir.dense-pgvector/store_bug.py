"""Intentionally broken store that mixes models with the same dimension."""


class VectorStore:
    def __init__(self, space_id: str, dimensions: int) -> None:
        self.space_id = space_id
        self.dimensions = dimensions
        self.rows: list[tuple[str, str, tuple[float, ...]]] = []

    def add(self, chunk_id: str, space_id: str, vector: tuple[float, ...]) -> None:
        if len(vector) != self.dimensions:
            raise ValueError("dimension mismatch")
        # BUG: equal dimensions do not imply the same embedding space.
        self.rows.append((chunk_id, space_id, vector))
