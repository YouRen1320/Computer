from model import device_value, first_year_at_most, inclusive_sum, repair_fee

assert [(h, repair_fee(h)) for h in (0, 1, 2, 3)] == [(0, 0), (1, 100), (2, 200), (3, 330)]
assert repair_fee(2) == 200
assert device_value(0) == 120_000
year = first_year_at_most(30_000)
assert device_value(year) <= 30_000 < device_value(year - 1)
assert inclusive_sum([1, 2, 3, 4]) == 10
print("piecewise boundary, inverse and inclusive sum: PASS")
