# fpga

VHDL för Real Digital Boolean Board (Spartan-7, `xc7s50csga324-1`), Vivado 2026.1.

| Fil | Vad | Status |
|---|---|---|
| `src/pdm_clock_gen.vhd` | Mikrofonklocka från 100 MHz: 1,5625 MHz vid start, sen 3,125 MHz | Simulerad |
| `src/pdm_pair_capture.vhd` | Läser en DATA-linje som delas av två mikrofoner | Simulerad |
| `sim/tb_pdm_pair_capture.vhd` | Testbänk med modell av två mikrofoner | – |
| `constraints/boolean_mic_array.xdc` | Pinnmall, **inga pinnar valda än** | Mall |

Inget av detta är testat i hårdvara.

## Simulera

```bash
fpga/sim/run_xsim.sh   # exit 0 och "PASS: ..." om allt stämmer
```

Skriptet sourcar `/tools/Xilinx/2026.1/Vivado/settings64.sh`. Sätt `VIVADO_SETTINGS`
om Vivado ligger någon annanstans. Varningen `Failure: "TIMEOUT"` från xelab är
bara elaboreringen som ser watchdog-raden, den betyder inte att testet fallerat.

Testbänken kollar klockperioden i båda lägena och att 200 bitar per kanal läses
korrekt. Med en för lång data-valid-tid (t.ex. 150 ns) fallerar den när klockan
går över till ultraljudsläge, vilket är väntat.

## Antaganden att verifiera

- Vilken SELECT-nivå som ger data efter stigande resp. fallande flank
- Mikrofonens data-valid-tid (testbänken antar 40 ns, marginalen är ca 130 ns vid 3,125 MHz)
- Frekvensintervall för standard- och ultraljudsläge, och hur länge mikrofonen ska gå i startläge
  (`STARTUP_CYCLES`, nu 10 ms)

## Vivado-projekt

Lägg inte in Vivados projektkataloger i git (de är ignorerade). Skapa projektet
lokalt och lägg till filerna från `src/` och `constraints/`, eller skriv ett
tcl-skript i `tools/` som bygger projektet.
