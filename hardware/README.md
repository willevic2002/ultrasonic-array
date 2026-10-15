# hardware

Licens: CERN-OHL-P-2.0 (se [LICENSE](LICENSE)).

## Var filerna ska ligga

| Fil | Plats |
|---|---|
| `mic_array.kicad_pcb` | `kicad/` |
| `place_mics.py`, `make_kicad_pcb.py` | `scripts/` |
| `mic_placement.csv` | här (`hardware/`) |
| Riktiga footprints (`.kicad_mod` / `.pretty`) | `footprints/` |

## Generera kortet

```bash
python3 hardware/scripts/place_mics.py     # -> hardware/mic_placement.csv
python3 hardware/scripts/make_kicad_pcb.py # -> hardware/kicad/mic_array.kicad_pcb
```

Skripten hittar sina filer relativt sig själva och kan köras från vilken mapp som helst.
`place_mics.py` återskapar exakt samma placering som första utkastet:
r = 8,5·√(i+0,5) mm, vinkel = i·137,508°, min. avstånd 13,14 mm.

Obs: `make_kicad_pcb.py` skriver över `mic_array.kicad_pcb`. Så fort du börjar
dra ledningar i KiCad ska du sluta köra skriptet (eller ändra det att skriva till en annan fil).

## Läge

`mic_array.kicad_pcb` är ett **utkast** genererat av `make_kicad_pcb.py`:

- 16 mikrofoner i Vogel-spiral, min. avstånd ca 13 mm, kort 84 x 84 mm
- Mikrofon-footprints är **platshållare med gissade pads**, måste bytas
- Inga ledningar, inget jordplan, ingen sändare/drivare, inga porthål

Öppna punkter finns i [../TODO.md](../TODO.md).

## Att komma ihåg (verifiera mot datablad)

- SPH0641LU4H-1 pinnar (enligt mina anteckningar): 1 DATA, 2 SELECT, 3 GND, 4 CLOCK, 5 VDD.
  VDD 1,62-3,6 V.
- Akustisk port på undersidan: hål i kortet under varje mikrofon.
- 0,1 µF C0G/NP0 vid varje VDD-pinne.
- Tvätta inte kortet efter lödning.
