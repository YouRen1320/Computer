import numpy as np


def loss(point: np.ndarray) -> float:
    x, y = point
    residual = 2 * x + y - 5
    return float(residual**2 + 0.5 * (x - 1) ** 2)


def correct_gradient(point: np.ndarray) -> np.ndarray:
    x, y = point
    residual = 2 * x + y - 5
    return np.array([4 * residual + (x - 1), 2 * residual])


def missing_chain_factor(point: np.ndarray) -> np.ndarray:
    x, y = point
    residual = 2 * x + y - 5
    return np.array([2 * residual + (x - 1), 2 * residual])


def central_difference(point: np.ndarray, h: float) -> np.ndarray:
    output = []
    for index in range(2):
        step = np.zeros(2)
        step[index] = h
        output.append((loss(point + step) - loss(point - step)) / (2 * h))
    return np.array(output)


point = np.array([1.0, 1.0])
oracle = np.array([-8.0, -4.0])
np.testing.assert_array_equal(correct_gradient(point), oracle)
finite = central_difference(point, 1e-5)
np.testing.assert_allclose(finite, oracle, atol=1e-7, rtol=1e-7)

# Fault 1: missing dx/dx=2 in the chain produces [-4,-4], caught component-wise.
wrong = missing_chain_factor(point)
np.testing.assert_array_equal(wrong, [-4.0, -4.0])
assert not np.allclose(wrong, finite, atol=1e-7)

# Fault 2: taking +gradient rather than -gradient raises the loss here.
learning_rate = 0.1
correct_step = point - learning_rate * oracle
wrong_step = point + learning_rate * oracle
assert loss(correct_step) < loss(point)
assert loss(wrong_step) > loss(point)

# Fault 3: a huge finite-difference step is inaccurate for general functions.
# This quadratic happens to be exact under central differences, so use sin as the h oracle.
def sine_difference(h: float) -> float:
    return (np.sin(h) - np.sin(-h)) / (2 * h)


assert abs(sine_difference(1e-5) - 1.0) < 1e-9
assert abs(sine_difference(1.0) - 1.0) > 0.1

# Fault 4: learning rate 0.3 is above the stable range for this quadratic.
def trajectory(rate: float, steps: int = 8) -> list[float]:
    current = point.copy()
    values = [loss(current)]
    for _ in range(steps):
        current -= rate * correct_gradient(current)
        values.append(loss(current))
    return values


good = trajectory(0.1)
bad = trajectory(0.3)
assert good[-1] < good[0]
assert bad[-1] > bad[0] * 1000

print("PASS gradients lab: chain, sign, h and learning-rate faults exposed")
