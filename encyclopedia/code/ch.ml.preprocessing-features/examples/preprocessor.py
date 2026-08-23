from dataclasses import dataclass

import pandas as pd


@dataclass
class Preprocessor:
    mean_: float | None = None
    categories_: tuple[str, ...] = ()

    def fit(self, frame: pd.DataFrame) -> "Preprocessor":
        self.mean_ = float(frame["age_days"].mean())
        self.categories_ = tuple(sorted(frame["category"].dropna().unique()))
        return self

    def transform(self, frame: pd.DataFrame) -> pd.DataFrame:
        if self.mean_ is None:
            raise RuntimeError("fit must be called before transform")
        result = pd.DataFrame(index=frame.index)
        result["age_centered"] = frame["age_days"].fillna(self.mean_) - self.mean_
        for category in self.categories_:
            result[f"category={category}"] = (frame["category"] == category).astype(int)
        result["category=__UNKNOWN__"] = (~frame["category"].isin(self.categories_) & frame["category"].notna()).astype(int)
        return result
