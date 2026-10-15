# hardware

Licens: CERN-OHL-P-2.0 (se [LICENSE](LICENSE)).

## Var filerna ska ligga

| Fil | Plats |
|---|---|
| `mic_array.kicad_pcb` | `kicad/` |
| `make_kicad_pcb.py`, `gen_layout.py`, `place_mics.py` | `scripts/` |
| `mic_placement.csv` | här (`hardware/`) |
| Riktiga footprints (`.kicad_mod` / `.pretty`) | `footprints/` |

Kör skripten från `hardware/` så att relativa sökvägar till `mic_placement.csv`
och `kicad/` stämmer (justera skripten om de antar något annat).

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
