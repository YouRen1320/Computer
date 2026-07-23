from functions import compound, linear, periods_to_target, slope

table = [(x, linear(x, 3, 5)) for x in (-1, 0, 1, 2)]
assert table == [(-1, 2), (0, 5), (1, 8), (2, 11)]
assert slope(table[0], table[-1]) == 3
assert abs(compound(1000, 0.05, 10) - 1628.894626777442) < 1e-9
n = periods_to_target(1000, 2000, 0.05)
assert abs(compound(1000, 0.05, n) - 2000) < 1e-9
print("function table, slope and logarithm inverse: PASS")
