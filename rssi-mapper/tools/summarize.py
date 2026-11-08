"""Summarize labeled SAMPLE lines saved from the left receiver's serial port."""

import json
import sys
from collections import defaultdict
from statistics import median


def summarize(lines):
    trials = defaultdict(list)
    for line in lines:
        if not line.startswith("SAMPLE,"):
            continue
        _, timestamp, session, trial, place, bias, data = line.strip().split(",", 6)
        sample = json.loads(data)
        valid = sample["online"] and None not in (sample["left"], sample["right"])
        delta = sample["right"] - sample["left"] - float(bias) if valid else None
        trials[session, trial, place].append((int(timestamp), delta))

    for (session, trial, place), rows in trials.items():
        values = [delta for _, delta in rows if delta is not None]
        zones = ["L" if x < -4 else "R" if x > 4 else "C" for x in values]
        summary = f"{session} #{trial} {place} valid={len(values)}/{len(rows)}"
        if values:
            summary += (f" correct={zones.count(place)}/{len(values)}"
                        f" L/C/R={zones.count('L')}/{zones.count('C')}/{zones.count('R')}"
                        f" median={median(values):+.1f}dB")
        print(summary)


if __name__ == "__main__":
    with open(sys.argv[1], encoding="utf-8", errors="replace") as log:
        summarize(log)
