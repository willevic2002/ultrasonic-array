# fpga

VHDL för Real Digital Boolean Board (Spartan-7, `xc7s50csga324-1`), Vivado 2026.1.

| Fil | Vad | Status |
|---|---|---|
| `src/pdm_clock_gen.vhd` | Mikrofonklocka från 100 MHz: 1,5625 MHz vid start, sen 3,125 MHz | Simulerad |
| `src/pdm_pair_capture.vhd` | Läser en DATA-linje som delas av två mikrofoner | Simulerad |
| `sim/tb_pdm_pair_capture.vhd` | Testbänk med modell av två mikrofoner | – |
| `sim/tb.wcfg` | Vågformsvy: mic_clk, sample/valid/bit per kanal, räknare | – |
| `constraints/boolean_mic_array.xdc` | Pinnmall, **inga pinnar valda än** | Mall |

Inget av detta är testat i hårdvara.

## Simulera

```bash
fpga/sim/run_xsim.sh   # exit 0 och "PASS: ..." om allt stämmer
```

Skriptet sourcar `/tools/Xilinx/2026.1/Vivado/settings64.sh`. Sätt `VIVADO_SETTINGS`
om Vivado ligger någon annanstans. Varningen `Failure: "TIMEOUT"` från xelab är
bara elaboreringen som ser watchdog-raden, den betyder inte att testet fallerat.

För att titta på vågformerna (efter `run_xsim.sh`):

```bash
cd fpga/sim/build && source /tools/Xilinx/2026.1/Vivado/settings64.sh
xsim tb -gui    # tb.wcfg laddas automatiskt, kör sen `run all`
```

Ändrar du vyn i GUI:t, spara den till `fpga/sim/tb.wcfg` (inte `build/`) så kommer den med i git.

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
