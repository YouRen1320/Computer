import pandas as pd

from encoder import StableEncoder


def test_unknown_category_maps_to_stable_unknown_column() -> None:
    encoder = StableEncoder().fit(pd.DataFrame({"category": ["A", "B"]}))
    result = encoder.transform(pd.DataFrame({"category": ["NEW"]}))
    assert result.columns.tolist() == ["A", "B", "__UNKNOWN__"]
    assert result.loc[0, "__UNKNOWN__"] == 1
