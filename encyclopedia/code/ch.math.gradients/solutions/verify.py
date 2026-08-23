import numpy as np

from solution import analytic_gradient, loss


point = np.array([1.0, 1.0])
h = 1e-5
finite = []
for index in range(2):
    step = np.zeros(2)
    step[index] = h
    finite.append((loss(point + step) - loss(point - step)) / (2 * h))
np.testing.assert_allclose(analytic_gradient(point), finite, atol=1e-7, rtol=1e-7)
print("PASS private gradients solution")
