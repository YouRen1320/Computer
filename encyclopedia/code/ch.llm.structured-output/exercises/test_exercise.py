import pytest
from pydantic import ValidationError

from exercise import ClassificationV1, parse


def test_exact_versioned_contract_is_accepted() -> None:
    value = parse('{"schema_version":"classification/1","category":"OTHER","priority":"LOW"}')
    assert isinstance(value, ClassificationV1)
    assert value.schema_version == "classification/1"


@pytest.mark.parametrize("raw", [
    '{"category":"OTHER","priority":"LOW"}',
    '{"schema_version":"classification/1","category":"OTHER","priority":"HIGH","x":1}',
    '{"schema_version":"classification/1","category":"UNKNOWN","priority":"LOW"}',
    '{"schema_version":"classification/1","category":"OTHER","priority":1}',
    'not-json',
])
def test_missing_extra_unknown_coerced_and_invalid_values_are_rejected(raw: str) -> None:
    with pytest.raises(ValidationError):
        parse(raw)
