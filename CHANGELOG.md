# Changelog

## [Unreleased]

### 2026-10-15
- Repo skapat: struktur, README, TODO, licenser (MIT + CERN-OHL-P-2.0), .gitignore.
- `fpga/`: `pdm_clock_gen` (startläge 1,5625 MHz → ultraljudsläge 3,125 MHz) och
  `pdm_pair_capture` (två mikrofoner per datalinje) med testbänk. Simulerad, otestad i hårdvara.
- `hardware/`: första utkastet av kortet (`mic_array.kicad_pcb`), `make_kicad_pcb.py` och nytt
  `place_mics.py` som återskapar `mic_placement.csv` exakt.
- `hardware/`: designkontroller i `hardware/tests` (KiCads DRC + nät, parning, avkoppling, avstånd).
  De hittade att U1 låg under sändaren. Spiralen flyttad till r = 8,5·√(i+1) mm, courtyards
  och keepout-zon för sändaren tillagda.
- `hardware/`: riktig footprint för SPH0641LU4H-1 (KiCads Knowles_LGA-5_3.5x2.65mm) med porthål.
  Porten (0,77 mm från kapselns mitt) placeras på spiralpunkten. Nytt testkort `mic_test.kicad_pcb`
  med 2 mikrofoner och Pmod-kontakt.
- Skiss av enheten (`docs/images/device_sketch.svg`, genererad av `tools/draw_sketch.py`).
- TODO-listan flyttad till GitHub Issues (#1-#14).
- `software/`: delay-and-sum offline med fokus på punkter (närfält), testad på syntetisk data.

### 2026-10-18
- `software/`: `sonar.matched.locate` ger avstånd (matchat filter) och riktning (delay-and-sum
  fokuserat på ekots avstånd). `python -m sonar --mics …` skriver ut båda (#12).
