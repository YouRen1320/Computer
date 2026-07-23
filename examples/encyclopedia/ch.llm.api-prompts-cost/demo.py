from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class Usage:
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int


def estimate_usd(usage: Usage, rates_per_million: dict[str, Decimal]) -> Decimal:
    """Price only from provider usage and a dated external rate snapshot."""
    uncached = usage.input_tokens - usage.cached_input_tokens
    numerator = (
        Decimal(uncached) * rates_per_million["input"]
        + Decimal(usage.cached_input_tokens) * rates_per_million["cached_input"]
        + Decimal(usage.output_tokens) * rates_per_million["output"]
    )
    return (numerator / Decimal(1_000_000)).quantize(Decimal("0.000001"))


def main() -> None:
    snapshot = {
        "input": Decimal("2.00"),
        "cached_input": Decimal("0.50"),
        "output": Decimal("8.00"),
    }
    usage = Usage(input_tokens=1000, cached_input_tokens=400, output_tokens=250)
    assert estimate_usd(usage, snapshot) == Decimal("0.003400")
    print({"model": "fixture-model-v1", "prompt_version": "classify-v3", "usage": usage})


if __name__ == "__main__":
    main()
