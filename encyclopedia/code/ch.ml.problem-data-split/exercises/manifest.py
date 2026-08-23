import pandas as pd


def broken_manifest() -> pd.DataFrame:
    # 练习缺口：同一实体的两个快照跨越训练集和测试集。
    return pd.DataFrame(
        {
            "sample_id": [1, 2, 3],
            "entity_id": [9, 10, 9],
            "split": ["train", "validation", "test"],
        }
    )
