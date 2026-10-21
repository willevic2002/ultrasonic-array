# Genererar KiCad-kort (KiCad 7-format):
#   kicad/mic_array.kicad_pcb  16 mikrofoner från mic_placement.csv
#   kicad/mic_test.kicad_pcb   testkort med 2 mikrofoner på samma DATA-linje, Pmod-kontakt
# Kör: python3 hardware/scripts/make_kicad_pcb.py
import csv, math, uuid
from pathlib import Path

HW = Path(__file__).resolve().parent.parent   # hardware/
TX_KEEPOUT_R = 7.25    # sändaren i mitten: Same Sky CUSA-T75-18-2400-TH Ø12,5 mm + 1 mm luft (#4)
PORT_DY = 0.77         # ljudportens läge relativt kapselns mitt (Knowles_LGA-5_3.5x2.65mm)

u = lambda: str(uuid.uuid4())
NETS = ["", "GND", "+3V3", "CLK"] + [f"DATA{i}" for i in range(1, 9)]
nid = {n: i for i, n in enumerate(NETS)}


def net(n): return f'(net {nid[n]} "{n}")'


def txt(kind, s, x, y, layer="F.SilkS", size=0.9):
    return (f'(property "{kind}" "{s}" (at {x} {y} 0) (layer "{layer}") '
            f'(effects (font (size {size} {size}) (thickness 0.15))))')


def crtyd(x0, y0, x1, y1):
    return (f'(fp_rect (start {x0} {y0}) (end {x1} {y1}) (stroke (width 0.05) (type default)) (fill none) '
            f'(layer "F.CrtYd") (tstamp {u()}))')


def header():
    return ['(kicad_pcb (version 20221018) (generator "make_kicad_pcb")',
            '(general (thickness 1.6))', '(paper "A4")',
            '(layers (0 "F.Cu" signal) (31 "B.Cu" signal) (32 "B.Adhes" user "B.Adhesive") (33 "F.Adhes" user "F.Adhesive") '
            '(34 "B.Paste" user) (35 "F.Paste" user) (36 "B.SilkS" user "B.Silkscreen") (37 "F.SilkS" user "F.Silkscreen") '
            '(38 "B.Mask" user) (39 "F.Mask" user) (40 "Dwgs.User" user "User.Drawings") (41 "Cmts.User" user "User.Comments") '
            '(42 "Eco1.User" user "User.Eco1") (43 "Eco2.User" user "User.Eco2") (44 "Edge.Cuts" user) (45 "Margin" user) '
            '(46 "B.CrtYd" user "B.Courtyard") (47 "F.CrtYd" user "F.Courtyard") (48 "B.Fab" user) (49 "F.Fab" user))',
            '(setup (pad_to_mask_clearance 0))'] + [f'(net {i} "{n}")' for i, n in enumerate(NETS)]


def outline(x0, y0, x1, y1):
    return [f'(gr_line (start {a[0]} {a[1]}) (end {b[0]} {b[1]}) (layer "Edge.Cuts") (width 0.1) (tstamp {u()}))'
            for a, b in [((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)), ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))]]


def silk(s, x, y, size=1.0):
    return f'(gr_text "{s}" (at {x} {y}) (layer "F.SilkS") (effects (font (size {size} {size}) (thickness 0.15))) (tstamp {u()}))'


def hole(ref, x, y):
    return (f'(footprint "MountingHole:MountingHole_3.2mm_M3" (layer "F.Cu") (at {x} {y}) {txt("Reference", ref, 0, -3.5, size=0.8)} '
            f'{txt("Value", "M3", 0, 3.5, "F.Fab", 0.8)} (attr exclude_from_pos_files exclude_from_bom) '
            f'(pad "" np_thru_hole circle (at 0 0) (size 3.2 3.2) (drill 3.2) (layers "*.Cu" "*.Mask")) '
            f'(fp_circle (center 0 0) (end 3.45 0) (stroke (width 0.05) (type default)) (fill none) (layer "F.CrtYd") (tstamp {u()})) '
            f'(tstamp {u()}))')


def cap(ref, x, y, n1, n2):
    return (f'(footprint "Capacitor_SMD:C_0603_1608Metric" (layer "F.Cu") (at {x:.3f} {y:.3f}) '
            f'{txt("Reference", ref, 0, -1.4, size=0.7)} {txt("Value", "100nF C0G", 0, 1.4, "F.Fab", 0.7)} (attr smd) '
            f'(pad "1" smd roundrect (at -0.775 0) (size 0.9 0.95) (layers "F.Cu" "F.Paste" "F.Mask") (roundrect_rratio 0.25) {net(n1)} (tstamp {u()})) '
            f'(pad "2" smd roundrect (at 0.775 0) (size 0.9 0.95) (layers "F.Cu" "F.Paste" "F.Mask") (roundrect_rratio 0.25) {net(n2)} (tstamp {u()})) '
            f'{crtyd(-1.48, -0.73, 1.48, 0.73)} (tstamp {u()}))')


def mic(ref, x, y, data, sel):
    # Sensor_Audio:Knowles_LGA-5_3.5x2.65mm ur KiCads bibliotek (efter Knowles datablad rev B),
    # i det här filformatet. Pads: 1 DATA, 2 SEL, 3 GND (ring runt porten), 4 CLOCK, 5 VDD.
    # Placeras så att ljudporten hamnar på (x, y), eftersom det är den som räknas akustiskt.
    pads = [("1", -0.8375, -1.304, data), ("2", -0.8375, -0.482, sel),
            ("4", 0.8375, -0.482, "CLK"), ("5", 0.8375, -1.304, "+3V3")]
    p = " ".join(f'(pad "{n}" smd rect (at {px} {py}) (size 0.725 0.522) (layers "F.Cu" "F.Paste" "F.Mask") {net(nn)} (tstamp {u()}))'
                 for n, px, py, nn in pads)
    gnd_ring = (f'(pad "3" smd custom (at 0 1.4325) (size 0.3 0.3) (layers "F.Cu" "F.Mask") {net("GND")} (zone_connect 0) '
                f'(options (clearance outline) (anchor circle)) '
                f'(primitives (gr_circle (center 0 -0.6625) (end 0.6625 -0.6625) (width 0.3) (fill none))) (tstamp {u()}))')
    port = f'(pad "" np_thru_hole circle (at 0 {PORT_DY}) (size 0.5 0.5) (drill 0.5) (layers "*.Cu" "*.Mask") (tstamp {u()}))'
    # Pasta på ringen i fyra bågar, så att lodet inte täpper till porten
    paste = " ".join(f'(fp_arc (start {s0}) (mid {m}) (end {e}) (stroke (width 0.3) (type solid)) (layer "F.Paste") (tstamp {u()}))'
                     for s0, m, e in [("-0.6 0.49", "-0.464769 0.298418", "-0.271239 0.165989"),
                                      ("-0.28 1.37", "-0.471582 1.234769", "-0.604011 1.041239"),
                                      ("0.28 0.17", "0.471401 0.305047", "0.603799 0.49829"),
                                      ("0.6 1.05", "0.464769 1.241582", "0.271239 1.374011")])
    return (f'(footprint "Sensor_Audio:Knowles_LGA-5_3.5x2.65mm" (layer "F.Cu") (at {x:.3f} {y - PORT_DY:.3f}) '
            f'{txt("Reference", ref, 0, -2.8, size=0.9)} {txt("Value", "SPH0641LU4H-1", 0, 3.0, "F.Fab", 0.7)} (attr smd) '
            f'(fp_rect (start -1.325 -1.75) (end 1.325 1.75) (stroke (width 0.1) (type default)) (fill none) (layer "F.Fab") (tstamp {u()})) '
            f'{crtyd(-1.58, -2.0, 1.58, 2.0)} {paste} {p} {gnd_ring} {port} (tstamp {u()}))')


def pin_header(ref, x, y, signals, value):
    n = len(signals)
    pads = " ".join(f'(pad "{i+1}" thru_hole {"rect" if i == 0 else "circle"} (at {i*2.54:.2f} 0) (size 1.7 1.7) (drill 1.0) '
                    f'(layers "*.Cu" "*.Mask") {net(s) if s else ""} (tstamp {u()}))' for i, s in enumerate(signals))
    mid = (n - 1) * 2.54 / 2
    return (f'(footprint "Connector_PinHeader_2.54mm:PinHeader_1x{n:02d}_P2.54mm_Vertical" (layer "F.Cu") (at {x:.2f} {y:.2f}) '
            f'{txt("Reference", ref, mid, -2.5)} {txt("Value", value, mid, 2.5, "F.Fab", 0.8)} '
            f'{crtyd(-1.8, -1.8, (n - 1) * 2.54 + 1.8, 1.8)} {pads} (tstamp {u()}))')


def tx_keepout(cx, cy, r):
    # Keepout i mitten: inga komponenter där sändaren ska sitta (KiCads DRC flaggar intrång)
    pts = " ".join(f'(xy {cx + r*math.cos(2*math.pi*k/32):.3f} {cy + r*math.sin(2*math.pi*k/32):.3f})' for k in range(32))
    return (f'(zone (net 0) (net_name "") (layers "F&B.Cu") (tstamp {u()}) (name "TX_KEEPOUT") (hatch edge 0.5) '
            f'(connect_pads (clearance 0)) (min_thickness 0.25) '
            f'(keepout (tracks allowed) (vias allowed) (pads not_allowed) (copperpour allowed) (footprints not_allowed)) '
            f'(fill (thermal_gap 0.5) (thermal_bridge_width 0.5)) (polygon (pts {pts})))')


def write(name, out):
    path = HW / "kicad" / name
    path.write_text("\n".join(out + [")"]))
    print("skrev", path)


def mic_array():
    cx, cy, half = 100.0, 100.0, 42.0     # kortets mitt och halv sidlängd (mm) -> 84 x 84 mm
    out = header() + outline(cx - half, cy - half, cx + half, cy + half)
    for i, (dx, dy) in enumerate([(4, 4), (-4, 4), (4, -4), (-4, -4)], 1):
        out.append(hole(f"H{i}", cx + (half - dx if dx > 0 else -half - dx), cy + (half - dy if dy > 0 else -half - dy)))
    for r in csv.DictReader(open(HW / "mic_placement.csv")):
        x, y = cx + float(r["x_mm"]), cy + float(r["y_mm"])
        sel = "GND" if r["SEL_pin"].startswith("GND") else "+3V3"
        out.append(mic(r["ref"], x, y, r["data_net"], sel))
        out.append(cap(f"C{r['ref'][1:]}", x + 4.0, y - PORT_DY, "+3V3", "GND"))
    # J1: 1x12 stiftlist 2,54 mm: CLK, DATA1-8, 3V3, GND, GND
    j1 = ["CLK"] + [f"DATA{i}" for i in range(1, 9)] + ["+3V3", "GND", "GND"]
    out.append(pin_header("J1", cx - 13.97, cy + half - 5, j1, "CLK D1-D8 3V3 GND GND"))
    out.append(tx_keepout(cx, cy, TX_KEEPOUT_R))
    out.append(silk("MIC ARRAY 16", 100, 62, 1.2))
    write("mic_array.kicad_pcb", out)


def mic_test():
    # Två mikrofoner på samma DATA-linje (U1 SEL=GND, U2 SEL=VDD), 14 mm isär som i arrayen.
    # J1 följer Digilents 6-pinnars Pmod: 1-4 signaler, 5 GND, 6 VCC (3,3 V). Verifiera mot Boolean (#5).
    cx, cy = 100.0, 100.0
    out = header() + outline(cx - 15, cy - 11, cx + 15, cy + 11)
    for ref, dx, sel in [("U1", -7.0, "GND"), ("U2", 7.0, "+3V3")]:
        out.append(mic(ref, cx + dx, cy - 3.0, "DATA1", sel))
        out.append(cap(f"C{ref[1:]}", cx + dx + 4.0, cy - 3.0 - PORT_DY, "+3V3", "GND"))
    out.append(pin_header("J1", cx - 6.35, cy + 6.5, ["CLK", "DATA1", None, None, "GND", "+3V3"], "PMOD 1 CLK 2 DATA 5 GND 6 3V3"))
    out.append(silk("SEL=GND", cx - 7, cy - 8.7, 0.8))
    out.append(silk("SEL=VDD", cx + 7, cy - 8.7, 0.8))
    out.append(silk("MIC TEST", cx, cy + 2.2, 0.8))
    for i, name in enumerate(["CLK", "DAT", "", "", "GND", "3V3"]):
        if name:
            out.append(silk(name, cx - 6.35 + i * 2.54, cy + 9.0, 0.8))
    write("mic_test.kicad_pcb", out)


if __name__ == "__main__":
    mic_array()
    mic_test()
