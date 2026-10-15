# ultrasonic-array

Egenbyggd 3D-ultraljudssensor för min robot: en 40 kHz-sändare och en array med
16 digitala MEMS-mikrofoner (PDM). Riktning och avstånd till hinder bestäms med
chirp, matchat filter och beamforming. Idén liknar Sonairs ADAR.

> **Lärprojekt.** Det här är ingen certifierad säkerhetsfunktion och ska inte
> användas som enda skydd mot kollisioner.

## Arkitektur

```
 40 kHz-givare ◄── drivare (TC4427A, 10-12 V) ◄── TX ─┐
                                                      │
 16 x SPH0641LU4H-1 ── 8 x DATA + 1 x CLK ──► FPGA (Boolean Board, Spartan-7)
   (Vogel-spiral, 84x84 mm)                    │  klockgenerering, PDM-inläsning,
                                               │  CIC-decimering
                                               ▼
                                         Raspberry Pi
                                           beamforming, loggning, (ROS 2)
```

- **Mikrofoner:** Knowles SPH0641LU4H-1, PDM med ultraljudsläge. Två mikrofoner delar
  en DATA-linje (SELECT väljer klockflank). 16 mikrofoner blir 8 DATA-linjer + 1 delad CLK.
- **Sändare:** Murata MA40S4S (not for new designs, ersättare ska väljas) och drivare
  med 10-12 V. Sitter i mitten av arrayen.
- **FPGA:** Real Digital Boolean Board (XC7S50, `xc7s50csga324-1`), VHDL i Vivado.
  Spartan-7 har ingen DFSDM-hårdvara, så PDM läses och decimeras i logiken.
- **Raspberry Pi:** tar emot decimerad data (länk inte bestämd än) och kör beamforming.

## Status

Ärligt läge, oktober 2026:

| Del | Status |
|---|---|
| Steg 1: en sändare + några mikrofoner på breakout-kort | ✅ Fungerar (utanför detta repo) |
| Steg 3: eget kort, 16 mikrofoner | 🚧 Utkast. Placering klar, footprints är platshållare, inga ledningar, inget jordplan, ingen sändare |
| `fpga/`: klockgenerator + PDM-inläsning för ett mikrofonpar | 🧪 Simulerad i xsim, **otestad i hårdvara** |
| `fpga/`: CIC-decimering, 8 datalinjer, länk till Pi | ❌ Inte påbörjat |
| `fpga/constraints/`: pinnar | ❌ Bara mall, pinnar inte valda |
| `software/`: delay-and-sum offline | 🧪 Testad på syntetisk data, **aldrig körd på riktig mätdata** |
| `software/`: chirp + matchat filter, ROS 2 | ❌ Inte påbörjat |

Alla tekniska fakta om mikrofonen och Boolean Board (pinnar, klockintervall,
tidsparametrar) ska verifieras mot datablad. Se [docs/datasheets.md](docs/datasheets.md).

## Repo-struktur

```
hardware/    KiCad-kort, footprints och genereringsskript (CERN-OHL-P)
fpga/        VHDL-källor, testbänkar, constraints
software/    Python: inläsning av loggdata och beamforming
docs/        datablad-länkar, anteckningar, bilder
tools/       hjälpskript
```

## Bygga och köra

### FPGA-simulering

Kräver Vivado 2026.1 (xsim). Se [fpga/README.md](fpga/README.md).

```bash
fpga/sim/run_xsim.sh
```

### Python

```bash
cd software
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
pytest
python -m beamforming data.npz --mics ../hardware/mic_placement.csv --range 1.0
```

### Kortet

Öppna `hardware/kicad/mic_array.kicad_pcb` i KiCad 10. Se [hardware/README.md](hardware/README.md).

## TODO

Se [TODO.md](TODO.md). Ändringar loggas i [CHANGELOG.md](CHANGELOG.md).

## Licens

- Kod (`fpga/`, `software/`, `tools/`): [MIT](LICENSE)
- Hårdvara (`hardware/`): [CERN-OHL-P-2.0](hardware/LICENSE)
