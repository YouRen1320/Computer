from starter import conditional_probability


event = [True, False, False, False, True, False]
condition = [True, True, True, True, False, False]
assert conditional_probability(event, condition) == 0.25
try:
    conditional_probability([True, False], [False, False])
except ValueError:
    pass
else:
    raise AssertionError("empty condition must be rejected")
