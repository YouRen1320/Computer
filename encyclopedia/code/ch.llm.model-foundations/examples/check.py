from simulator import probabilities, sample_counts, tokenize

assert tokenize("Factory Care工单?") == ["Factory", " ", "Care", "工", "单", "?"]
assert len("Factory Care工单?") != len(tokenize("Factory Care工单?"))
low = probabilities([2, 1, 0], 0.5)
high = probabilities([2, 1, 0], 2.0)
assert low[0] > high[0]
counts = sample_counts([2, 1, 0], 1.0, 20_000, 7)
observed = [count / 20_000 for count in counts]
expected = probabilities([2, 1, 0], 1.0)
assert all(abs(a - b) < 0.015 for a, b in zip(observed, expected, strict=True))
print("toy tokenizer and sampling simulation: PASS")
