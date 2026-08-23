from budget import fits_context

assert not fits_context(6, 7, 2, 0)
assert fits_context(5, 7, 2, 0)
print("token-record based budget private solution: PASS")
