import pandas as pd


class WorkOrderPipeline:
    required = ("priority", "age_days", "category")

    def __init__(self) -> None:
        self.age_median_: float | None = None
        self.age_mean_: float | None = None
        self.age_std_: float | None = None
        self.categories_: tuple[str, ...] = ()

    @property
    def feature_names_out(self) -> tuple[str, ...]:
        return ("priority", "age_z", *(f"category={c}" for c in self.categories_), "category=__UNKNOWN__")

    def fit(self, frame: pd.DataFrame) -> "WorkOrderPipeline":
        self._validate(frame)
        self.age_median_ = float(frame["age_days"].median())
        filled = frame["age_days"].fillna(self.age_median_)
        self.age_mean_ = float(filled.mean())
        self.age_std_ = float(filled.std(ddof=0)) or 1.0
        self.categories_ = tuple(sorted(frame["category"].dropna().unique()))
        return self

    def transform(self, frame: pd.DataFrame) -> pd.DataFrame:
        self._validate(frame)
        if self.age_median_ is None or self.age_mean_ is None or self.age_std_ is None:
            raise RuntimeError("pipeline is not fitted")
        result = pd.DataFrame(index=frame.index)
        result["priority"] = frame["priority"].astype(float)
        age = frame["age_days"].fillna(self.age_median_)
        result["age_z"] = (age - self.age_mean_) / self.age_std_
        for value in self.categories_:
            result[f"category={value}"] = (frame["category"] == value).astype(float)
        result["category=__UNKNOWN__"] = (~frame["category"].isin(self.categories_) & frame["category"].notna()).astype(float)
        return result.loc[:, self.feature_names_out]

    def _validate(self, frame: pd.DataFrame) -> None:
        missing = set(self.required) - set(frame.columns)
        if missing:
            raise ValueError(f"missing required columns: {sorted(missing)}")
