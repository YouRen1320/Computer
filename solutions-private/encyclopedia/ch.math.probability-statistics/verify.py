from solution import conditional_probability


assert conditional_probability(
    [True, False, False, False, True, False],
    [True, True, True, True, False, False],
) == 0.25
try:
    conditional_probability([True], [False])
except ValueError:
    pass
else:
    raise AssertionError("undefined conditional probability accepted")
print("PASS private probability-statistics solution")
