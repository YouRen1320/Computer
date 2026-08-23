import pandas as pd


class StableEncoder:
    def fit(self, frame: pd.DataFrame) -> "StableEncoder":
        self.categories_ = tuple(sorted(frame["category"].dropna().unique()))
        return self

    def transform(self, frame: pd.DataFrame) -> pd.DataFrame:
        result = pd.DataFrame(index=frame.index)
        for value in self.categories_:
            result[value] = (frame["category"] == value).astype(int)
        result["__UNKNOWN__"] = (~frame["category"].isin(self.categories_) & frame["category"].notna()).astype(int)
        return result
