import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from index_bug import document_frequency


documents = {"D1": "pump pump pump", "D2": "seal"}
actual = document_frequency(documents, "pump")
if actual != 1:
    raise AssertionError(f"EXPECTED RED: df counts documents, expected 1 but got {actual}")
print("PASS: document frequency counts documents")
