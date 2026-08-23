import pandas as pd

from encoder import BrokenEncoder


def test_unknown_category_maps_to_stable_unknown_column() -> None:
    encoder = BrokenEncoder().fit(pd.DataFrame({"category": ["A", "B"]}))
    result = encoder.transform(pd.DataFrame({"category": ["NEW"]}))
    assert result.columns.tolist() == ["A", "B", "__UNKNOWN__"], "unknown category must not change shape or crash"
    assert result.loc[0, "__UNKNOWN__"] == 1
