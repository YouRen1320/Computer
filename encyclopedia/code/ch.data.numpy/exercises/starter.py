import numpy as np


def mean_per_day(values: np.ndarray) -> np.ndarray:
    # TODO: 应折叠 technician 轴，并验证二维输入。
    return np.nanmean(values, axis=1)
