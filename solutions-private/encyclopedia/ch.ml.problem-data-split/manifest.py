import pandas as pd


def grouped_manifest() -> pd.DataFrame:
    # 整个实体分配到同一集合；这里清单固定，便于复核。
    return pd.DataFrame(
        {
            "sample_id": [1, 2, 3],
            "entity_id": [9, 10, 9],
            "split": ["train", "validation", "train"],
        }
    )
