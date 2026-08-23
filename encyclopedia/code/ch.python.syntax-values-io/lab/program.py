"""Emit a trace for basic Python binding semantics."""

import json

unit_price_text = "1999"
print(json.dumps({"name": "unit_price_text", "type": type(unit_price_text).__name__, "value": unit_price_text}))
quantity_text = "3"
print(json.dumps({"name": "quantity_text", "type": type(quantity_text).__name__, "value": quantity_text}))
unit_price_cents = int(unit_price_text)
print(json.dumps({"name": "unit_price_cents", "type": type(unit_price_cents).__name__, "value": unit_price_cents}))
quantity = int(quantity_text)
print(json.dumps({"name": "quantity", "type": type(quantity).__name__, "value": quantity}))
total_cents = unit_price_cents * quantity
print(json.dumps({"name": "total_cents", "type": type(total_cents).__name__, "value": total_cents}))
