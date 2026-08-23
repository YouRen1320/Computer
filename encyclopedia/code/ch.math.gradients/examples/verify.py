import platform

import numpy as np

from quadratic import analytic_gradient, central_difference, descend, loss


point = np.array([1.0, 1.0])
# Hand oracle: residual=2*1+1-5=-2, so f=4 and gradient=[4*(-2)+0, 2*(-2)]=[-8,-4].
assert loss(point) == 4.0
np.testing.assert_array_equal(analytic_gradient(point), [-8.0, -4.0])
np.testing.assert_allclose(
    analytic_gradient(point),
    central_difference(loss, point, h=1e-5),
    rtol=1e-7,
    atol=1e-7,
)

_, slow = descend(point, 0.01, 12)
_, useful = descend(point, 0.1, 12)
_, divergent = descend(point, 0.3, 12)
assert slow[-1] < slow[0]
assert useful[-1] < useful[0]
assert useful[1] < slow[1]
assert divergent[-1] > divergent[0] * 1000

print(
    f"PASS gradients example: Python {platform.python_version()}, NumPy {np.__version__}; "
    f"losses={slow[-1]:.6f}/{useful[-1]:.6f}/{divergent[-1]:.1f}"
)
