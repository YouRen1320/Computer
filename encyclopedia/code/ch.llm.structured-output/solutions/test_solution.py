import pytest
from pydantic import ValidationError

from solution import Priority, parse


def test_solution_accepts_exact_contract() -> None:
    value = parse('{"schema_version":"classification/1","category":"OTHER","priority":"LOW"}')
    assert value.priority is Priority.LOW


@pytest.mark.parametrize("raw", [
    '{"category":"OTHER","priority":"LOW"}',
    '{"schema_version":"classification/1","category":"OTHER","priority":"HIGH","x":1}',
    'not-json',
])
def test_solution_rejects_invalid(raw: str) -> None:
    with pytest.raises(ValidationError):
        parse(raw)
