import pandas as pd
import pytest

from pipeline import WorkOrderPipeline


@pytest.fixture
def fitted() -> WorkOrderPipeline:
    train = pd.DataFrame({"priority": [1, 5, 3], "age_days": [0.0, 10.0, None], "category": ["A", "B", "A"]})
    return WorkOrderPipeline().fit(train)


def test_heldout_extreme_and_unknown_do_not_refit(fitted: WorkOrderPipeline) -> None:
    before = (fitted.age_median_, fitted.age_mean_, fitted.categories_)
    result = fitted.transform(pd.DataFrame({"category": ["NEW"], "priority": [4], "age_days": [10_000.0]}))
    assert (fitted.age_median_, fitted.age_mean_, fitted.categories_) == before
    assert tuple(result.columns) == fitted.feature_names_out
    assert result.loc[0, "category=__UNKNOWN__"] == 1


def test_input_column_reordering_does_not_change_output(fitted: WorkOrderPipeline) -> None:
    a = pd.DataFrame({"priority": [2], "age_days": [5.0], "category": ["A"]})
    b = a[["category", "priority", "age_days"]]
    pd.testing.assert_frame_equal(fitted.transform(a), fitted.transform(b))
