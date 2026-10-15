# Genererar mic_array.kicad_pcb (KiCad 7-format) från mic_placement.csv
import csv, math, uuid
from pathlib import Path
HW = Path(__file__).resolve().parent.parent   # hardware/
CX, CY, HALF = 100.0, 100.0, 42.0       # kortets mitt och halv sidlängd (mm) -> 84 x 84 mm
TX_KEEPOUT_R = 6.0                      # sändaren i mitten: MA40S4S Ø10 mm + 1 mm luft. Ändra vid annan sändare (#4)
u = lambda: str(uuid.uuid4())
nets = ["", "GND", "+3V3", "CLK"] + [f"DATA{i}" for i in range(1, 9)]
nid = {n: i for i, n in enumerate(nets)}
def net(n): return f'(net {nid[n]} "{n}")'
def txt(kind, s, x, y, layer="F.SilkS", size=0.9):
    return (f'(property "{kind}" "{s}" (at {x} {y} 0) (layer "{layer}") '
            f'(effects (font (size {size} {size}) (thickness 0.15))))')

out = ['(kicad_pcb (version 20221018) (generator "claude_script")',
 '(general (thickness 1.6))', '(paper "A4")',
 '(layers (0 "F.Cu" signal) (31 "B.Cu" signal) (32 "B.Adhes" user "B.Adhesive") (33 "F.Adhes" user "F.Adhesive") '
 '(34 "B.Paste" user) (35 "F.Paste" user) (36 "B.SilkS" user "B.Silkscreen") (37 "F.SilkS" user "F.Silkscreen") '
 '(38 "B.Mask" user) (39 "F.Mask" user) (40 "Dwgs.User" user "User.Drawings") (41 "Cmts.User" user "User.Comments") '
 '(42 "Eco1.User" user "User.Eco1") (43 "Eco2.User" user "User.Eco2") (44 "Edge.Cuts" user) (45 "Margin" user) '
 '(46 "B.CrtYd" user "B.Courtyard") (47 "F.CrtYd" user "F.Courtyard") (48 "B.Fab" user) (49 "F.Fab" user))',
 '(setup (pad_to_mask_clearance 0))']
out += [f'(net {i} "{n}")' for i, n in enumerate(nets)]

# kortkant
x0, x1, y0, y1 = CX-HALF, CX+HALF, CY-HALF, CY+HALF
for a, b in [((x0,y0),(x1,y0)), ((x1,y0),(x1,y1)), ((x1,y1),(x0,y1)), ((x0,y1),(x0,y0))]:
    out.append(f'(gr_line (start {a[0]} {a[1]}) (end {b[0]} {b[1]}) (layer "Edge.Cuts") (width 0.1) (tstamp {u()}))')

def crtyd(x0, y0, x1, y1):
    return (f'(fp_rect (start {x0} {y0}) (end {x1} {y1}) (stroke (width 0.05) (type default)) (fill none) '
            f'(layer "F.CrtYd") (tstamp {u()}))')

def hole(ref, x, y):
    return (f'(footprint "MountingHole:MountingHole_3.2mm_M3" (layer "F.Cu") (at {x} {y}) {txt("Reference", ref, 0, -3.5, size=0.8)} '
            f'{txt("Value", "M3", 0, 3.5, "F.Fab", 0.8)} (attr exclude_from_pos_files exclude_from_bom) '
            f'(pad "" np_thru_hole circle (at 0 0) (size 3.2 3.2) (drill 3.2) (layers "*.Cu" "*.Mask")) '
            f'(fp_circle (center 0 0) (end 3.45 0) (stroke (width 0.05) (type default)) (fill none) (layer "F.CrtYd") (tstamp {u()})) '
            f'(tstamp {u()}))')
for i, (dx, dy) in enumerate([(4,4), (-4,4), (4,-4), (-4,-4)], 1):
    out.append(hole(f"H{i}", CX + (HALF-dx if dx>0 else -HALF-dx), CY + (HALF-dy if dy>0 else -HALF-dy)))

def cap(ref, x, y, n1, n2):
    return (f'(footprint "Capacitor_SMD:C_0603_1608Metric" (layer "F.Cu") (at {x:.3f} {y:.3f}) '
            f'{txt("Reference", ref, 0, -1.4, size=0.7)} {txt("Value", "100nF C0G", 0, 1.4, "F.Fab", 0.7)} (attr smd) '
            f'(pad "1" smd roundrect (at -0.775 0) (size 0.9 0.95) (layers "F.Cu" "F.Paste" "F.Mask") (roundrect_rratio 0.25) {net(n1)} (tstamp {u()})) '
            f'(pad "2" smd roundrect (at 0.775 0) (size 0.9 0.95) (layers "F.Cu" "F.Paste" "F.Mask") (roundrect_rratio 0.25) {net(n2)} (tstamp {u()})) '
            f'{crtyd(-1.48, -0.73, 1.48, 0.73)} '
            f'(tstamp {u()}))')

def mic(ref, x, y, data, sel):
    # OBS: platshållar-footprint! Pad-positioner är gissade. Byt mot riktig footprint (pad 1-5 behåller nät).
    pads = [("1", -1.2, -0.8, data), ("2", -1.2, 0.8, sel), ("3", 0.0, 0.95, "GND"), ("4", 1.2, 0.8, "CLK"), ("5", 1.2, -0.8, "+3V3")]
    p = " ".join(f'(pad "{n}" smd rect (at {px} {py}) (size 0.5 0.5) (layers "F.Cu" "F.Paste" "F.Mask") {net(nn)} (tstamp {u()}))'
                 for n, px, py, nn in pads)
    return (f'(footprint "PLACEHOLDER:SPH0641LU4H-1" (layer "F.Cu") (at {x:.3f} {y:.3f}) '
            f'{txt("Reference", ref, 0, 3.0, size=0.9)} {txt("Value", "SPH0641LU4H-1 PLACEHOLDER", 0, -3.0, "F.Fab", 0.7)} (attr smd) '
            f'(fp_rect (start -1.75 -1.325) (end 1.75 1.325) (stroke (width 0.1) (type default)) (fill none) (layer "F.Fab") (tstamp {u()})) '
            f'{crtyd(-2.0, -1.575, 2.0, 1.575)} {p} (tstamp {u()}))')

rows = list(csv.DictReader(open(HW / "mic_placement.csv")))
for r in rows:
    ref = r["ref"]; n = ref[1:]
    x, y = CX + float(r["x_mm"]), CY + float(r["y_mm"])
    sel = "GND" if r["SEL_pin"].startswith("GND") else "+3V3"
    out.append(mic(ref, x, y, r["data_net"], sel))
    out.append(cap(f"C{n}", x + 4.0, y, "+3V3", "GND"))

# J1: 1x12 stiftlist 2,54 mm: CLK, DATA1-8, 3V3, GND, GND
j1 = ["CLK"] + [f"DATA{i}" for i in range(1, 9)] + ["+3V3", "GND", "GND"]
pads = " ".join(f'(pad "{i+1}" thru_hole {"rect" if i==0 else "circle"} (at {i*2.54:.2f} 0) (size 1.7 1.7) (drill 1.0) '
                f'(layers "*.Cu" "*.Mask") {net(n)} (tstamp {u()}))' for i, n in enumerate(j1))
out.append(f'(footprint "Connector_PinHeader_2.54mm:PinHeader_1x12_P2.54mm_Vertical" (layer "F.Cu") (at {CX-13.97:.2f} {CY+HALF-5}) '
           f'{txt("Reference", "J1", 13.97, -2.5)} {txt("Value", "CLK D1-D8 3V3 GND GND", 13.97, 2.5, "F.Fab", 0.8)} {crtyd(-1.8, -1.8, 29.74, 1.8)} {pads} (tstamp {u()}))')
# Keepout i mitten: inga komponenter där sändaren ska sitta (KiCads DRC flaggar intrång)
pts = " ".join(f'(xy {CX + TX_KEEPOUT_R*math.cos(2*math.pi*k/32):.3f} {CY + TX_KEEPOUT_R*math.sin(2*math.pi*k/32):.3f})' for k in range(32))
out.append(f'(zone (net 0) (net_name "") (layers "F&B.Cu") (tstamp {u()}) (name "TX_KEEPOUT") (hatch edge 0.5) '
           f'(connect_pads (clearance 0)) (min_thickness 0.25) '
           f'(keepout (tracks allowed) (vias allowed) (pads not_allowed) (copperpour allowed) (footprints not_allowed)) '
           f'(fill (thermal_gap 0.5) (thermal_bridge_width 0.5)) (polygon (pts {pts})))')
out.append('(gr_text "MIC ARRAY 16" (at 100 62) (layer "F.SilkS") (effects (font (size 1.2 1.2) (thickness 0.2))) (tstamp %s))' % u())
out.append(')')
open(HW / "kicad" / "mic_array.kicad_pcb", "w").write("\n".join(out))
print("skrev", HW / "kicad" / "mic_array.kicad_pcb")
