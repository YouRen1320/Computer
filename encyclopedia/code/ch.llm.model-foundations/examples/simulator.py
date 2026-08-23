import math
import random


VOCAB = ("Factory", "Care", "工", "单", " ", "?")


def tokenize(text: str) -> list[str]:
    result: list[str] = []
    cursor = 0
    while cursor < len(text):
        match = next((token for token in VOCAB if text.startswith(token, cursor)), None)
        if match is None:
            raise ValueError(f"unknown text at character {cursor}")
        result.append(match)
        cursor += len(match)
    return result


def probabilities(logits: list[float], temperature: float) -> list[float]:
    if temperature <= 0:
        raise ValueError("temperature must be positive in this simulator")
    scaled = [value / temperature for value in logits]
    maximum = max(scaled)
    weights = [math.exp(value - maximum) for value in scaled]
    total = sum(weights)
    return [weight / total for weight in weights]


def sample_counts(logits: list[float], temperature: float, draws: int, seed: int) -> list[int]:
    rng = random.Random(seed)
    counts = [0] * len(logits)
    for choice in rng.choices(range(len(logits)), weights=probabilities(logits, temperature), k=draws):
        counts[choice] += 1
    return counts
