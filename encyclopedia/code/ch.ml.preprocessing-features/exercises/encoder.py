import pandas as pd


class BrokenEncoder:
    def fit(self, frame: pd.DataFrame) -> "BrokenEncoder":
        self.categories_ = tuple(sorted(frame["category"].unique()))
        return self

    def transform(self, frame: pd.DataFrame) -> pd.DataFrame:
        unknown = set(frame["category"]) - set(self.categories_)
        if unknown:
            # 练习缺口：线上正常出现的新类别导致整个批次崩溃。
            raise ValueError(f"unknown categories: {sorted(unknown)}")
        return pd.get_dummies(frame["category"]).reindex(columns=self.categories_, fill_value=False)
