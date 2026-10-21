# hardware

Licens: CERN-OHL-P-2.0 (se [LICENSE](LICENSE)).

## Var filerna ska ligga

| Fil | Plats |
|---|---|
| `mic_array.kicad_pcb` (16 mikrofoner), `mic_test.kicad_pcb` (testkort, 2 mikrofoner) | `kicad/` |
| `place_mics.py`, `make_kicad_pcb.py` | `scripts/` |
| `mic_placement.csv` | här (`hardware/`) |
| Riktiga footprints (`.kicad_mod` / `.pretty`) | `footprints/` |

## Generera kortet

```bash
python3 hardware/scripts/place_mics.py     # -> hardware/mic_placement.csv
python3 hardware/scripts/make_kicad_pcb.py # -> hardware/kicad/mic_array.kicad_pcb + mic_test.kicad_pcb
```

Skripten hittar sina filer relativt sig själva och kan köras från vilken mapp som helst.
`place_mics.py` placerar mikrofonerna i en Vogel-spiral: r = 8,5·√(i+1,5) mm,
vinkel = i·137,508°. Min. avstånd 13,95 mm, innersta mikrofonen 10,4 mm från mitten.
Första utkastet hade √(i+0,5), men då hamnade U1 under sändaren.

Mikrofonerna använder KiCads footprint `Sensor_Audio:Knowles_LGA-5_3.5x2.65mm`
(efter Knowles datablad rev B), med 0,5 mm hål under ljudporten och jordring runt det.
Porten sitter 0,77 mm från kapselns mitt. Footprinten placeras så att **porten**
hamnar på positionen i `mic_placement.csv`, så csv:n anger de akustiska positionerna.

`make_kicad_pcb.py` lägger också in courtyards och en keepout-zon (`TX_KEEPOUT`,
radie 7,25 mm) i mitten där sändaren ska sitta. Radien förutsätter Same Sky
CUSA-T75-18-2400-TH (Ø12,5 mm) och ska ändras om en annan sändare väljs (#4).

## Testa designen

```bash
pytest hardware/tests
```

Kör KiCads DRC via `kicad-cli` och kontrollerar det DRC inte kan veta utan schema:
nät per mikrofon, att varje DATA-par har en GND- och en VDD-SEL, avkoppling,
minsta avstånd, att allt ryms på kortet och att mitten är fri för sändaren.
Tillåtna DRC-avvikelser i utkastet: oanslutna nät (inga ledningar än) och
platshållar-footprints som saknas i bibliotek. När det finns ett schema kan
parity och ERC ta över en del av kontrollerna.

Obs: `make_kicad_pcb.py` skriver över `mic_array.kicad_pcb`. Så fort du börjar
dra ledningar i KiCad ska du sluta köra skriptet (eller ändra det att skriva till en annan fil).

## Läge

`mic_array.kicad_pcb` är ett **utkast** genererat av `make_kicad_pcb.py`:

- 16 mikrofoner i Vogel-spiral, min. avstånd 13,9 mm, kort 84 x 84 mm
- Courtyards och keepout för sändaren i mitten
- Riktig mikrofon-footprint med porthål
- Inga ledningar, inget jordplan, ingen sändare/drivare

## Testkort (`mic_test.kicad_pcb`)

30 x 22 mm med 2 mikrofoner på samma DATA-linje (U1 SEL=GND, U2 SEL=VDD), 14 mm isär,
en 100 nF per mikrofon och en 1x6 stiftlist med 2,54 mm delning enligt Digilents
Pmod-standard: 1 CLK, 2 DATA, 5 GND, 6 3V3. Passar i breadboard och i Boolean-kortets
Pmod-kontakt (verifiera pinout och 3,3 V). Syftet är att testa footprint, porthål,
SEL-parning och VHDL-inläsningen innan 16-mikrofonskortet beställs.

Öppna punkter finns i [../TODO.md](../TODO.md).

## Att komma ihåg (verifiera mot datablad)

- SPH0641LU4H-1 pinnar (enligt mina anteckningar): 1 DATA, 2 SELECT, 3 GND, 4 CLOCK, 5 VDD.
  VDD 1,62-3,6 V.
- Akustisk port på undersidan: hål i kortet under varje mikrofon.
- 0,1 µF C0G/NP0 vid varje VDD-pinne.
- Tvätta inte kortet efter lödning.
