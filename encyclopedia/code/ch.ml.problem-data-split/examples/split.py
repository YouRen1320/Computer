import pandas as pd


def temporal_split(frame: pd.DataFrame) -> pd.DataFrame:
    data = frame.copy()
    data["cutoff_at"] = pd.to_datetime(data["cutoff_at"], utc=True)
    data["split"] = "test"
    data.loc[data["cutoff_at"] < "2026-03-01T00:00:00Z", "split"] = "validation"
    data.loc[data["cutoff_at"] < "2026-02-01T00:00:00Z", "split"] = "train"
    return data
