import pandas as pd

from preprocessor import Preprocessor


def test_fit_state_is_learned_only_from_training_data() -> None:
    train = pd.DataFrame({"age_days": [0.0, 10.0], "category": ["A", "B"]})
    heldout = pd.DataFrame({"age_days": [10_000.0], "category": ["NEW"]})
    pipe = Preprocessor().fit(train)

    transformed = pipe.transform(heldout)

    assert pipe.mean_ == 5.0
    assert transformed.columns.tolist() == ["age_centered", "category=A", "category=B", "category=__UNKNOWN__"]
    assert transformed.loc[0, "category=__UNKNOWN__"] == 1
