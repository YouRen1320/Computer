"""Classify every supported and invalid priority boundary."""

for priority in range(0, 7):
    if priority < 1 or priority > 5:
        label = "INVALID"
    elif priority >= 4:
        label = "URGENT"
    elif priority >= 2:
        label = "NORMAL"
    else:
        label = "LOW"

    print(f"{priority}:{label}")
