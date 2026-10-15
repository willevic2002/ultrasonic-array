# Ritar docs/images/device_sketch.svg: skiss av sensorenheten i tre vyer.
# Mikrofonernas positioner läses från hardware/mic_placement.csv, så vy A är skalenlig.
import csv
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
mics = [(float(r["x_mm"]), float(r["y_mm"])) for r in csv.DictReader(open(ROOT / "hardware" / "mic_placement.csv"))]

INK, MUTED, BOARD, ENCL, TX, FOV, ACCENT = "#1f2328", "#6e7781", "#2e7d4f", "#d0d7de", "#b08800", "#f2cc60", "#cf222e"
svg = []
add = svg.append


def text(x, y, s, size=13, anchor="middle", color=INK, weight="normal"):
    add(f'<text x="{x:.1f}" y="{y:.1f}" font-size="{size}" text-anchor="{anchor}" fill="{color}" font-weight="{weight}">{s}</text>')


def wedge(cx, cy, r, a0, a1, fill, opacity):
    x0, y0 = cx + r * math.cos(math.radians(a0)), cy + r * math.sin(math.radians(a0))
    x1, y1 = cx + r * math.cos(math.radians(a1)), cy + r * math.sin(math.radians(a1))
    add(f'<path d="M{cx:.1f},{cy:.1f} L{x0:.1f},{y0:.1f} A{r},{r} 0 0 1 {x1:.1f},{y1:.1f} Z" fill="{fill}" fill-opacity="{opacity}" stroke="{TX}" stroke-width="1"/>')


W, H = 1240, 620
add(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" font-family="Helvetica, Arial, sans-serif">')
add(f'<rect width="{W}" height="{H}" fill="#ffffff"/>')
text(W / 2, 32, "Skiss: 3D-ultraljudssensor (kupol framåt, som Sonair ADAR)", 20, weight="bold")

# --- A: framifrån, skalenlig ---
s, cx, cy = 3.4, 210, 290
text(cx, 70, "A. Framifrån (skalenlig)", 15, weight="bold")
e = 96 / 2 * s
add(f'<rect x="{cx-e}" y="{cy-e}" width="{2*e}" height="{2*e}" rx="14" fill="{ENCL}" stroke="{MUTED}"/>')
b = 84 / 2 * s
add(f'<rect x="{cx-b}" y="{cy-b}" width="{2*b}" height="{2*b}" fill="{BOARD}" fill-opacity="0.18" stroke="{BOARD}"/>')
for hx, hy in [(38, 38), (-38, 38), (38, -38), (-38, -38)]:
    add(f'<circle cx="{cx+hx*s}" cy="{cy+hy*s}" r="{1.6*s}" fill="#ffffff" stroke="{MUTED}"/>')
for mx, my in mics:
    add(f'<rect x="{cx+(mx-1.75)*s:.1f}" y="{cy+(my-1.325)*s:.1f}" width="{3.5*s}" height="{2.65*s}" fill="none" stroke="{INK}" stroke-width="0.8" stroke-dasharray="2 1.5"/>')
    add(f'<circle cx="{cx+mx*s:.1f}" cy="{cy+my*s:.1f}" r="2.2" fill="{INK}"/>')
add(f'<circle cx="{cx}" cy="{cy}" r="{6*s}" fill="none" stroke="{ACCENT}" stroke-dasharray="4 3"/>')
add(f'<circle cx="{cx}" cy="{cy}" r="{5*s}" fill="{TX}" fill-opacity="0.85" stroke="{INK}"/>')
add(f'<circle cx="{cx}" cy="{cy}" r="{3.2*s}" fill="none" stroke="#ffffff" stroke-width="1.5"/>')
text(cx, cy + 4, "TX", 12, color="#ffffff", weight="bold")
text(cx, cy + e + 26, "96 x 96 mm hölje, 84 x 84 mm kort", 12, color=MUTED)
text(cx, cy + e + 44, "16 mikrofonportar (Vogel-spiral) + 40 kHz-sändare i mitten", 12, color=MUTED)
text(cx, cy + e + 62, "streckat = mikrofonen sitter bakom kortet", 12, color=MUTED)

# --- B: från sidan ---
s, cy, front = 2.9, 290, 600
text(620, 70, "B. Från sidan", 15, weight="bold")
wedge(front, cy, 175, -65, 65, FOV, 0.35)
wedge(front, cy, 175, -65, -50, FOV, 0.25)
wedge(front, cy, 175, 50, 65, FOV, 0.25)
h, d = 96 / 2 * s, 24 * s
add(f'<rect x="{front-d}" y="{cy-h}" width="{d}" height="{2*h}" rx="8" fill="{ENCL}" stroke="{MUTED}"/>')
pcb = front - 4 * s
add(f'<rect x="{pcb-1.6*s:.1f}" y="{cy-84/2*s}" width="{1.6*s:.1f}" height="{84*s}" fill="{BOARD}"/>')
for my in (-30, -14, 0, 14, 30):
    add(f'<rect x="{pcb-1.6*s-1.0*s:.1f}" y="{cy+my*s-1.75*s:.1f}" width="{1.0*s:.1f}" height="{3.5*s:.1f}" fill="{INK}"/>')
    add(f'<line x1="{pcb-1.6*s:.1f}" y1="{cy+my*s:.1f}" x2="{front:.1f}" y2="{cy+my*s:.1f}" stroke="{INK}" stroke-width="1" stroke-dasharray="2 2"/>')
add(f'<rect x="{pcb:.1f}" y="{cy-5*s}" width="{7*s:.1f}" height="{10*s}" rx="3" fill="{TX}" stroke="{INK}"/>')
add(f'<rect x="{front-d-26}" y="{cy+h-28}" width="26" height="8" fill="{MUTED}"/>')
text(front - d - 30, cy + h - 32, "kabel till FPGA", 11, "end", MUTED)
text(front + 92, cy - 44, "kupol ±60–70°", 13, color=INK)
text(front + 92, cy - 28, "(svagare mot kanten)", 11, color=MUTED)
text(front - d / 2, cy - h - 12, "hölje ~24 mm", 11, color=MUTED)
text(front + 4, cy + h + 26, "mikrofoner på insidan, ljudet går", 11, "middle", MUTED)
text(front + 4, cy + h + 40, "in genom hål i kortet (bottom port)", 11, "middle", MUTED)
text(front + 92, cy + 30, "fram →", 13, weight="bold")

# --- C: robot uppifrån, 4 enheter ---
rcx, rcy, rw, rh = 1025, 318, 100, 130
text(rcx, 70, "C. Robot uppifrån, 4 enheter (ej skalenlig)", 15, weight="bold")
units = [(rcx - rw / 2, rcy - rh / 2, -135), (rcx + rw / 2, rcy - rh / 2, -45),
         (rcx + rw / 2, rcy + rh / 2, 45), (rcx - rw / 2, rcy + rh / 2, 135)]
for ux, uy, a in units:
    wedge(ux, uy, 150, a - 65, a + 65, FOV, 0.22)
add(f'<rect x="{rcx-rw/2}" y="{rcy-rh/2}" width="{rw}" height="{rh}" rx="18" fill="#ffffff" stroke="{INK}" stroke-width="2"/>')
for ux, uy, a in units:
    add(f'<rect x="{ux-12}" y="{uy-5}" width="24" height="10" fill="{TX}" stroke="{INK}" transform="rotate({a+90} {ux} {uy})"/>')
text(rcx, rcy - 6, "robot", 14, weight="bold")
text(rcx, rcy + 12, "↑ fram", 12, color=MUTED)
text(rcx, rcy - rh / 2 - 22, "död zon", 11, color=ACCENT)
add(f'<line x1="{rcx}" y1="{rcy-rh/2-18}" x2="{rcx}" y2="{rcy-rh/2-4}" stroke="{ACCENT}"/>')
text(rcx, 560, "enheter i hörnen, vinklade 45°: kupolerna överlappar en bit ut,", 12, color=MUTED)
text(rcx, 576, "men nära robotens sidor finns en smal död zon", 12, color=MUTED)
text(rcx, 592, "enheterna turas om att sända så att de inte stör varandra", 12, color=MUTED)

add("</svg>")
out = ROOT / "docs" / "images" / "device_sketch.svg"
out.write_text("\n".join(svg))
print(f"skrev {out}")
