"""Count valid and urgent priorities until the q sentinel."""

valid_count = 0
urgent_count = 0

while True:
    raw = input().strip().lower()
    if raw == "q":
        break

    priority = int(raw)
    if priority < 1 or priority > 5:
        print("INVALID")
        continue

    valid_count += 1
    if priority >= 4:
        urgent_count += 1

    assert 0 <= urgent_count <= valid_count

print(f"valid={valid_count},urgent={urgent_count}")
