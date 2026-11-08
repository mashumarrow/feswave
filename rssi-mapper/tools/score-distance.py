"""Evaluate a held-out return walk using the outbound RSSI differences."""
import json
import sys
from collections import defaultdict
from statistics import median


def load_stops(lines):
    stops = defaultdict(list)
    for line in lines:
        row = json.loads(line)
        if row["online"] and None not in (row["left"], row["right"]):
            stops[row["pass"], row["m"]].append(row["right"] - row["left"])
    return {key: median(values) for key, values in stops.items()}


def score(stops, spacing, length=5, calibration=("out",), validation="back"):
    points = [i * spacing for i in range(round(length / spacing) + 1)]
    if any((direction, m) not in stops for direction in (*calibration, validation) for m in points):
        return
    template = {p: median(stops[d, p] for d in calibration) for p in points}
    errors = []
    correct = 0
    tied = 0
    for m in points:
        measured = stops[validation, m]
        distances = [abs(template[p] - measured) for p in points]
        winners = [p for p, d in zip(points, distances) if abs(d - min(distances)) < 1e-6]
        if len(winners) > 1:
            tied += 1
        elif winners[0] == m:
            correct += 1
        print(f"  {m:g} m -> {winners} m")
        errors.append(max(abs(p - m) for p in winners))
    print(f"{spacing:g} m: {correct}/{len(points)} unique correct, {tied} ties, "
          f"median absolute error {median(errors):g} m, worst {max(errors):g} m")


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as stream:
        stops = load_stops(stream)
    four_meters = "--4m" in sys.argv[2:]
    for direction in (("out", "back", "test") if four_meters else ("out", "back")):
        print(direction, sorted((m, round(value, 1)) for (p, m), value in stops.items() if p == direction))
    if four_meters:
        for spacing in (2, 1):
            score(stops, spacing, 4, ("out", "back"), "test")
    else:
        for spacing in (2.5, 1, 0.5):
            score(stops, spacing)
