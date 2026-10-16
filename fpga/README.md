# fpga

VHDL för Real Digital Boolean Board (Spartan-7, `xc7s50csga324-1`), Vivado 2026.1.

Hela kedjan och SPI-protokollet beskrivs i [docs/pipeline.md](../docs/pipeline.md).

| Fil | Vad | Status |
|---|---|---|
| `src/mic_array_top.vhd` | Toppnivå: klocka, 8 linjer, 16 CIC, inspelning/SPI, chirp | Simulerad, syntetiserad |
| `src/pdm_clock_gen.vhd` | Mikrofonklocka från 100 MHz: 1,5625 MHz vid start, sen 3,125 MHz | Simulerad |
| `src/pdm_pair_capture.vhd` | Läser en DATA-linje som delas av två mikrofoner | Simulerad |
| `src/cic_decimator.vhd` | CIC N=4, R=32: PDM -> int16 i 97,66 kHz | Simulerad, bitexakt mot Python |
| `src/chirp_gen.vhd` | Chirp 38 -> 42 kHz, 1 ms, differentiellt till drivaren | Simulerad |
| `src/capture_spi.vhd`, `src/spi_slave.vhd` | Inspelning till BRAM, SPI-kommandon STATUS/PING/READ | Simulerad |
| `src/mic_array_pkg.vhd` | Gemensamma typer (`sample_array`) | – |
| `sim/tb_*.vhd` | Självkontrollerande testbänkar per modul | – |
| `sim/e2e_mic_array_top.vhd`, `sim/e2e.py`, `sim/run_e2e.sh` | Hela kedjan: eko i Python -> toppnivån via SPI -> kontroll | – |
| `sim/tb_pdm_pair_capture.wcfg` | Vågformsvy: mic_clk, sample/valid/bit per kanal, räknare | – |
| `constraints/boolean_mic_array.xdc` | Pinnar på PMOD JA/JB/JC, **verifiera mot manualen** | Utläst ur schemat |
| `tools/build.sh` | Syntes, place & route, bitström. Exit 0 bara om timing uppfylls | – |

Inget av detta är testat i hårdvara.

## Hela kedjan och bygget

```bash
PYTHON=<python med numpy> fpga/sim/run_e2e.sh   # eko -> FPGA -> SPI -> bitexakt + avstånd/riktning
fpga/tools/build.sh                             # bitström i fpga/build/, rapporter där också
```

Senaste bygget: timing uppfylls (WNS 0,996 ns vid 100 MHz). 2 927 LUT (9 %), 3 901 vippor (6 %),
16 BRAM36 (21 %), 0 DSP.

## Simulera

```bash
fpga/sim/run_xsim.sh                       # alla testbänkar, exit 0 om alla ger PASS
fpga/sim/run_xsim.sh tb_pdm_pair_capture   # bara en
```

Skriptet sourcar `/tools/Xilinx/2026.1/Vivado/settings64.sh`. Sätt `VIVADO_SETTINGS`
om Vivado ligger någon annanstans. Varningen `Failure: "TIMEOUT"` från xelab är
bara elaboreringen som ser watchdog-raden, den betyder inte att testet fallerat.

För att titta på vågformerna (efter `run_xsim.sh`):

```bash
cd fpga/sim/build/tb_pdm_pair_capture && source /tools/Xilinx/2026.1/Vivado/settings64.sh
xsim tb_pdm_pair_capture -gui    # <tb>.wcfg laddas automatiskt, kör sen `run all`
```

Ändrar du vyn i GUI:t, spara den till `fpga/sim/<tb>.wcfg` (inte `build/`) så kommer den med i git.

Testbänken kollar klockperioden i båda lägena och att 200 bitar per kanal läses
korrekt. Med en för lång data-valid-tid (t.ex. 150 ns) fallerar den när klockan
går över till ultraljudsläge, vilket är väntat.

## Kontrollerat mot databladet

SPH0641LU4H-1, rev B (se `docs/datasheets.md`):

- SELECT = VDD: data efter stigande flank (kanal `r`). SELECT = GND: data efter fallande flank (kanal `f`).
  SELECT har intern pull-down men får inte lämnas flytande.
- Data-valid tDD 18-40 ns. Testbänken använder max (40 ns), marginalen är ca 130 ns vid 3,125 MHz.
- Linjen släpps 3-16 ns (tDZ) efter nästa flank. Vi läser 20-30 ns före flanken, så det krockar inte.
- Standardläge 1,024-2,475 MHz (vi kör 1,5625), ultraljudsläge 3,072-4,8 MHz (vi kör 3,125).
  Pulskvot 48-52 % över 2,4 MHz, delaren ger 50 %.
- Wake-up max 15 ms: `STARTUP_CYCLES` är 20 ms.
- Mode-Change Time max 10 ms: **kasta de första 10 ms data efter att `ultrasonic` gått hög.**

Kvar att verifiera i hårdvara: allt ovan på en riktig mikrofon, och klockans flanktid (max 3 ns) över kabeln.

## Vivado-projekt

Lägg inte in Vivados projektkataloger i git (de är ignorerade). Skapa projektet
lokalt och lägg till filerna från `src/` och `constraints/`, eller skriv ett
tcl-skript i `tools/` som bygger projektet.
