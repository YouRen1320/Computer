import pandas as pd


def safe_enrich(orders: pd.DataFrame, devices: pd.DataFrame) -> pd.DataFrame:
    # TODO: 声明 many_to_one 基数，并保证 left join 不改变工单行数。
    return orders.merge(devices, how="left", on="device_id")
