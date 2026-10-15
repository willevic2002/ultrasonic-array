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
- TODO-listan flyttad till GitHub Issues (#1-#14).
- `software/`: delay-and-sum offline med fokus på punkter (närfält), testad på syntetisk data.
