from summation import sum_one_through

assert sum_one_through(0) == 0
assert sum_one_through(1) == 1
assert sum_one_through(4) == 10
assert sum_one_through(100) == 100 * 101 // 2
print("inclusive summation private solution: PASS")
