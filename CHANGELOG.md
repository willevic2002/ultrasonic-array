# Changelog

## [Unreleased]

### 2026-10-15
- Repo skapat: struktur, README, TODO, licenser (MIT + CERN-OHL-P-2.0), .gitignore.
- `fpga/`: `pdm_clock_gen` (startläge 1,5625 MHz → ultraljudsläge 3,125 MHz) och
  `pdm_pair_capture` (två mikrofoner per datalinje) med testbänk. Simulerad, otestad i hårdvara.
- `software/`: delay-and-sum offline med fokus på punkter (närfält), testad på syntetisk data.
