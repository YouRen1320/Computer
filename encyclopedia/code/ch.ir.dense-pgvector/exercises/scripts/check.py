import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from store_bug import VectorStore


store = VectorStore("model-a@1", 3)
store.add("C1", "model-a@1", (1.0, 0.0, 0.0))
try:
    store.add("C2", "model-b@9", (1.0, 0.0, 0.0))
except ValueError:
    pass
else:
    raise AssertionError("EXPECTED RED: equal dimensions must not permit a different embedding space")
print("PASS: incompatible embedding space is rejected")
