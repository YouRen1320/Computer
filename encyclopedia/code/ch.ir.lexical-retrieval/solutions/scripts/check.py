import pathlib
import sys


root = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root))
from index_fixed import document_frequency


documents = {"D1": "pump pump pump", "D2": "seal", "D3": "pump motor"}
assert document_frequency(documents, "pump") == 2
assert document_frequency(documents, "seal") == 1
assert document_frequency(documents, "absent") == 0
assert all(document_frequency(documents, term) <= len(documents) for term in ("pump", "seal", "absent"))
print("PASS: df counts documents once and respects zero/N bounds")
