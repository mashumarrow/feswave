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


def score(stops, spacing):
    points = [i * spacing for i in range(round(5 / spacing) + 1)]
    if any((direction, m) not in stops for direction in ("out", "back") for m in points):
        return
    errors = []
    correct = 0
    tied = 0
    for m in points:
        measured = stops["back", m]
        distances = [abs(stops["out", p] - measured) for p in points]
        winners = [p for p, d in zip(points, distances) if abs(d - min(distances)) < 1e-6]
        if len(winners) > 1:
            tied += 1
        elif winners[0] == m:
            correct += 1
        errors.append(max(abs(p - m) for p in winners))
    print(f"{spacing:g} m: {correct}/{len(points)} unique correct, {tied} ties, "
          f"median absolute error {median(errors):g} m, worst {max(errors):g} m")


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8") as stream:
        stops = load_stops(stream)
    for direction in ("out", "back"):
        print(direction, sorted((m, round(value, 1)) for (p, m), value in stops.items() if p == direction))
    for spacing in (2.5, 1, 0.5):
        score(stops, spacing)
