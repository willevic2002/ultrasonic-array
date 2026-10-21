# Genererar hardware/mic_placement.csv: 16 mikrofoner i en Vogel-spiral.
# r_i = 8,5 * sqrt(i + 1,5) mm, vinkel_i = i * gyllene vinkeln. Ger min. avstånd ca 13,9 mm,
# innersta mikrofonen på 10,4 mm (plats för sändaren CUSA-T75, Ø12,5 mm, i mitten) och
# ytterradie 34,5 mm, vilket ryms på det 84 x 84 mm stora kortet.
# Första utkastet hade sqrt(i + 0,5): då hamnade U1 under sändaren. sqrt(i + 1) räckte för MA40S4S (Ø10 mm).
#
# Varje DATA-linje delas av två mikrofoner: den första i paret får SEL mot GND,
# den andra SEL mot VDD. Parningen nedan är tagen från första utkastet av kortet
# (mikrofoner som ligger nära varandra delar linje).
import csv
import itertools
import math
from pathlib import Path

N = 16
SCALE_MM = 8.5
RADIUS_OFFSET = 1.5
GOLDEN_ANGLE = math.radians(137.508)  # avrundad gyllene vinkel
MIN_SPACING_MM = 13.0

# (första mikrofonen, andra mikrofonen) per DATA-linje, 1-indexerat
PAIRS = [(1, 4), (2, 7), (3, 8), (5, 13), (6, 14), (9, 12), (10, 15), (11, 16)]

out = Path(__file__).resolve().parent.parent / "mic_placement.csv"

pos = [(SCALE_MM * math.sqrt(i + RADIUS_OFFSET) * math.cos(i * GOLDEN_ANGLE),
        SCALE_MM * math.sqrt(i + RADIUS_OFFSET) * math.sin(i * GOLDEN_ANGLE)) for i in range(N)]
min_d = min(math.dist(a, b) for a, b in itertools.combinations(pos, 2))
assert min_d >= MIN_SPACING_MM, f"min. avstånd {min_d:.2f} mm < {MIN_SPACING_MM} mm"
assert sorted(m for p in PAIRS for m in p) == list(range(1, N + 1)), "varje mikrofon ska finnas i exakt ett par"

net_of = {}
for k, (first, second) in enumerate(PAIRS, 1):
    net_of[first] = (f"DATA{k}", "GND")
    net_of[second] = (f"DATA{k}", "VDD")

with open(out, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["ref", "x_mm", "y_mm", "data_net", "SEL_pin"])
    for i, (x, y) in enumerate(pos, 1):
        w.writerow([f"U{i}", f"{x:.3f}", f"{y:.3f}", *net_of[i]])
print(f"skrev {out} (min. avstånd {min_d:.2f} mm)")
