"""Designkontroller av hardware/kicad/mic_array.kicad_pcb.

Kör KiCads DRC (kicad-cli) och kollar sådant DRC inte kan veta utan ett
schema: nät per mikrofon, DATA-parning, avkoppling och avstånd.
Kör: pytest hardware/tests
"""

import csv
import itertools
import math
import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

HW = Path(__file__).resolve().parent.parent
PCB = HW / "kicad" / "mic_array.kicad_pcb"
TEST_PCB = HW / "kicad" / "mic_test.kicad_pcb"

CENTER = (100.0, 100.0)  # kortets mitt i make_kicad_pcb.py
MIC_BODY = (2.65, 3.5)  # SPH0641LU4H-1 (bredd x höjd i footprinten), mm
PORT_DY = 0.77  # ljudporten sitter 0,77 mm från kapselns mitt
CAP_BODY = (1.6 + 0.9, 0.95)  # 0603 inkl. pads, ungefär
TX_DIAMETER = 12.5  # Same Sky CUSA-T75-18-2400-TH, mm (#4)
TX_CLEARANCE = 1.0  # luft runt sändaren, mm
MIN_MIC_SPACING = 13.0
EDGE_MARGIN = 1.0
CAP_MAX_DIST = 5.0  # max avstånd mikrofon -> dess avkopplingskondensator, mm


def parse_sexpr(text):
    tokens = re.findall(r'\(|\)|"(?:[^"\\]|\\.)*"|[^\s()]+', text)
    stack = [[]]
    for t in tokens:
        if t == "(":
            stack.append([])
        elif t == ")":
            node = stack.pop()
            stack[-1].append(node)
        else:
            stack[-1].append(t[1:-1] if t.startswith('"') else t)
    return stack[0][0]


def children(node, name):
    return [c for c in node if isinstance(c, list) and c and c[0] == name]


def child(node, name):
    found = children(node, name)
    return found[0] if found else None


def load_board(path=PCB):
    root = parse_sexpr(path.read_text())
    parts = {}
    for fp in children(root, "footprint"):
        ref = next(p[2] for p in children(fp, "property") if p[1] == "Reference")
        at = child(fp, "at")
        pads = {}
        for pad in children(fp, "pad"):
            net = child(pad, "net")
            pads[pad[1]] = net[2] if net else None
        parts[ref] = {"lib": fp[1], "x": float(at[1]), "y": float(at[2]),
                      "rot": float(at[3]) if len(at) > 3 else 0.0, "pads": pads}
    edges = [(float(child(l, "start")[1]), float(child(l, "start")[2]),
              float(child(l, "end")[1]), float(child(l, "end")[2]))
             for l in children(root, "gr_line") if child(l, "layer")[1] == "Edge.Cuts"]
    xs = [v for e in edges for v in (e[0], e[2])]
    ys = [v for e in edges for v in (e[1], e[3])]
    return parts, (min(xs), min(ys), max(xs), max(ys))


PARTS, OUTLINE = load_board()
MICS = {r: p for r, p in PARTS.items() if r.startswith("U")}
CAPS = {r: p for r, p in PARTS.items() if r.startswith("C")}


def box(p, size):
    w, h = size if p["rot"] % 180 == 0 else size[::-1]
    return (p["x"] - w / 2, p["y"] - h / 2, p["x"] + w / 2, p["y"] + h / 2)


def overlap(a, b):
    return a[0] < b[2] and b[0] < a[2] and a[1] < b[3] and b[1] < a[3]


def test_part_counts():
    assert len(MICS) == 16
    assert len(CAPS) == 16
    assert "J1" in PARTS


def test_mic_power_and_clock_nets():
    for ref, m in MICS.items():
        assert m["pads"]["3"] == "GND", ref
        assert m["pads"]["4"] == "CLK", ref
        assert m["pads"]["5"] == "+3V3", ref


def test_each_data_line_has_one_gnd_and_one_vdd_select():
    by_net = {}
    for ref, m in MICS.items():
        by_net.setdefault(m["pads"]["1"], []).append(m["pads"]["2"])
    assert sorted(by_net) == [f"DATA{i}" for i in range(1, 9)]
    for net, sels in by_net.items():
        assert sorted(sels) == ["+3V3", "GND"], f"{net}: SELECT {sels}"


def test_every_mic_has_nearby_decoupling_cap():
    for ref, m in MICS.items():
        cap = CAPS[f"C{ref[1:]}"]
        assert sorted(cap["pads"].values()) == ["+3V3", "GND"], ref
        d = math.dist((m["x"], m["y"]), (cap["x"], cap["y"]))
        assert d <= CAP_MAX_DIST, f"{ref}: kondensatorn sitter {d:.1f} mm bort"


def test_connector_carries_all_signals():
    nets = set(PARTS["J1"]["pads"].values())
    assert {"CLK", "+3V3", "GND", *(f"DATA{i}" for i in range(1, 9))} <= nets


def test_min_mic_spacing():
    worst = min(math.dist((a["x"], a["y"]), (b["x"], b["y"]))
                for a, b in itertools.combinations(MICS.values(), 2))
    assert worst >= MIN_MIC_SPACING, f"min. avstånd {worst:.2f} mm"


def test_positions_match_placement_csv():
    with open(HW / "mic_placement.csv") as f:
        for row in csv.DictReader(f):
            m = MICS[row["ref"]]
            assert m["x"] == pytest.approx(CENTER[0] + float(row["x_mm"]), abs=1e-3), row["ref"]
            # positionerna i csv:n är ljudportarnas, inte kapslarnas
            assert m["y"] + PORT_DY == pytest.approx(CENTER[1] + float(row["y_mm"]), abs=1e-3), row["ref"]
            assert m["pads"]["1"] == row["data_net"], row["ref"]
            assert m["pads"]["2"] == ("GND" if row["SEL_pin"] == "GND" else "+3V3"), row["ref"]


def test_parts_inside_board():
    x0, y0, x1, y1 = OUTLINE
    for ref in [*MICS, *CAPS]:
        b = box(PARTS[ref], MIC_BODY if ref.startswith("U") else CAP_BODY)
        assert b[0] >= x0 + EDGE_MARGIN and b[2] <= x1 - EDGE_MARGIN, ref
        assert b[1] >= y0 + EDGE_MARGIN and b[3] <= y1 - EDGE_MARGIN, ref


def test_no_overlapping_mics_and_caps():
    boxes = {r: box(PARTS[r], MIC_BODY if r.startswith("U") else CAP_BODY) for r in [*MICS, *CAPS]}
    clashes = [(a, b) for a, b in itertools.combinations(boxes, 2) if overlap(boxes[a], boxes[b])]
    assert not clashes, f"överlappar: {clashes}"


def test_center_free_for_transmitter():
    keep_out = TX_DIAMETER / 2 + TX_CLEARANCE
    too_close = []
    for ref, p in [*MICS.items(), *CAPS.items()]:
        x0, y0, x1, y1 = box(p, MIC_BODY if ref.startswith("U") else CAP_BODY)
        # närmaste punkt i komponentens rektangel till kortets mitt
        nx, ny = min(max(CENTER[0], x0), x1), min(max(CENTER[1], y0), y1)
        d = math.dist(CENTER, (nx, ny))
        if d < keep_out:
            too_close.append(f"{ref} ({d:.1f} mm)")
    assert not too_close, f"inom {keep_out} mm från sändaren i mitten: {too_close}"


# Förväntat i utkastet: inga ledningar (unconnected) och platshållar-footprints
# som inte finns i något bibliotek. Allt annat är ett riktigt fel.
ALLOWED_DRC = {"lib_footprint_mismatch", "lib_footprint_issues"}


@pytest.mark.skipif(shutil.which("kicad-cli") is None, reason="kicad-cli saknas")
@pytest.mark.parametrize("board", [PCB, TEST_PCB], ids=lambda p: p.stem)
def test_kicad_drc(tmp_path, board):
    report = tmp_path / "drc.json"
    subprocess.run(["kicad-cli", "pcb", "drc", "--format", "json", "--severity-all",
                    "-o", str(report), str(board)], check=True, capture_output=True)
    violations = json.loads(report.read_text())["violations"]
    errors = [f"{v['type']}: {v['description']} {[i['description'] for i in v['items']]}"
              for v in violations if v["type"] not in ALLOWED_DRC]
    assert not errors, "\n".join(errors)


def test_test_board_pairs_two_mics_on_pmod():
    parts, _ = load_board(TEST_PCB)
    mics = {r: p for r, p in parts.items() if r.startswith("U")}
    assert sorted(m["pads"]["2"] for m in mics.values()) == ["+3V3", "GND"]
    assert {m["pads"]["1"] for m in mics.values()} == {"DATA1"}
    for ref, m in mics.items():
        assert (m["pads"]["3"], m["pads"]["4"], m["pads"]["5"]) == ("GND", "CLK", "+3V3"), ref
        assert sorted(parts[f"C{ref[1:]}"]["pads"].values()) == ["+3V3", "GND"], ref
    # Digilent Pmod 1x6: 1-4 signaler, 5 GND, 6 VCC
    j1 = parts["J1"]["pads"]
    assert (j1["1"], j1["2"], j1["5"], j1["6"]) == ("CLK", "DATA1", "GND", "+3V3")
