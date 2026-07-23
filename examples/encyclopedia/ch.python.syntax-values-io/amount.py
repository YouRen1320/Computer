"""Calculate a maintenance amount using only basic bindings and I/O."""

work_order_code = input("工单号：").strip()
unit_price_text = input("单价（分）：")
quantity_text = input("数量：")
service_fee_text = input("服务费（分）：")

unit_price_cents = int(unit_price_text)
quantity = int(quantity_text)
service_fee_cents = int(service_fee_text)
total_cents = (unit_price_cents * quantity) + service_fee_cents

print(f"工单：{work_order_code}")
print(f"输入类型：{type(unit_price_text).__name__}/{type(quantity_text).__name__}")
print(f"总金额：{total_cents} 分")
