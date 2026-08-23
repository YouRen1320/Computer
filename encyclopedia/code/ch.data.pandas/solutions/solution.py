import pandas as pd


def safe_enrich(orders: pd.DataFrame, devices: pd.DataFrame) -> pd.DataFrame:
    result = orders.merge(
        devices,
        how="left",
        on="device_id",
        validate="many_to_one",
        indicator=True,
    )
    if len(result) != len(orders):
        raise AssertionError("many-to-one left join changed row count")
    return result
