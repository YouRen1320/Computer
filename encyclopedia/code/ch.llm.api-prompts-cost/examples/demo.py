from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class Usage:
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int
    total_tokens: int | None = None

    def __post_init__(self) -> None:
        values = (self.input_tokens, self.cached_input_tokens, self.output_tokens)
        if any(isinstance(value, bool) or not isinstance(value, int) or value < 0 for value in values):
            raise ValueError("usage token counts must be non-negative integers")
        if self.cached_input_tokens > self.input_tokens:
            raise ValueError("cached_input_tokens cannot exceed input_tokens")
        if self.total_tokens is not None:
            if isinstance(self.total_tokens, bool) or not isinstance(self.total_tokens, int) or self.total_tokens < 0:
                raise ValueError("total_tokens must be a non-negative integer")
            if self.total_tokens != self.input_tokens + self.output_tokens:
                raise ValueError("provider total_tokens does not match input_tokens + output_tokens")


def estimate_usd(usage: Usage, rates_per_million: dict[str, Decimal]) -> Decimal:
    """Price only from provider usage and a dated external rate snapshot."""
    expected_rates = {"input", "cached_input", "output"}
    if set(rates_per_million) != expected_rates:
        raise ValueError("rate snapshot must contain exactly input, cached_input and output")
    if any(not isinstance(rate, Decimal) or not rate.is_finite() or rate < 0
           for rate in rates_per_million.values()):
        raise ValueError("rates must be finite non-negative Decimal values")
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
    usage = Usage(input_tokens=1000, cached_input_tokens=400, output_tokens=250,
                  total_tokens=1250)
    assert estimate_usd(usage, snapshot) == Decimal("0.003400")
    for invalid in (
        {"input_tokens": -1, "cached_input_tokens": 0, "output_tokens": 0},
        {"input_tokens": 1, "cached_input_tokens": 2, "output_tokens": 0},
        {"input_tokens": 1, "cached_input_tokens": 0, "output_tokens": 1,
         "total_tokens": 3},
    ):
        try:
            Usage(**invalid)
        except ValueError:
            pass
        else:
            raise AssertionError(f"invalid usage escaped: {invalid}")
    print({"model": "fixture-model-v1", "prompt_version": "classify-v3", "usage": usage})


if __name__ == "__main__":
    main()
