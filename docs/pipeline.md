# Signalkedjan: från mikrofon till riktning

Specifikation för hela flödet. FPGA-koden, Pi-koden och simuleringarna ska följa
den här filen. Ändra här först om något i kedjan ändras.

```
Pi (SPI-master)                 FPGA (Boolean Board, 100 MHz)                     Mikrofonkort
───────────────                 ─────────────────────────────                     ────────────
STATUS / PING / READ ──SPI──►   capture_spi ──chirp_start──► chirp_gen ──tx_p/tx_n──► drivare → givare
                                     ▲  BRAM 16 x N_SAMPLES x int16
                                     │ samples, sample_valid
                                cic_decimator x16 (÷32)
                                     ▲ bit, valid
                                pdm_pair_capture x8 ◄──pdm_data[7:0]── 16 x SPH0641
                                pdm_clock_gen ─────────mic_clk──────►
```

## 1. Kanalnumrering

DATA-linje `DATAk` (k = 1..8) går till `pdm_data[k-1]`. På varje linje:

| Mikrofon | SELECT | Driver efter | Signal i `pdm_pair_capture` | Kanal |
|---|---|---|---|---|
| "r" | VDD | stigande flank | `bit_r` | `2*(k-1)` |
| "f" | GND | fallande flank | `bit_f` | `2*(k-1) + 1` |

Vilken mikrofon (U1-U16) som är vilken kanal räknas fram ur kolumnerna `data_net` och
`SEL_pin` i `hardware/mic_placement.csv`. Ingen tabell skrivs för hand.

## 2. Klockor och tider

| Storhet | Värde | Var |
|---|---|---|
| Systemklocka | 100 MHz | Boolean, pinne F14 |
| mic_clk, startläge | 1,5625 MHz (delning 64) | `pdm_clock_gen` |
| mic_clk, ultraljudsläge | 3,125 MHz (delning 32) | `pdm_clock_gen` |
| Startfas | 20 ms (`STARTUP_CYCLES = 2_000_000`) | databladet: wake-up max 15 ms |
| Vänta efter lägesbyte | 10 ms (`SETTLE_CYCLES = 1_000_000`) | databladet: mode-change max 10 ms |
| Samplingsfrekvens efter CIC | 3,125 MHz / 32 = **97 656,25 Hz** | |
| Inspelning per ping | `N_SAMPLES = 2048` sampel ≈ 21,0 ms ≈ 3,6 m räckvidd (tur och retur) | |

## 3. CIC-decimering (bitexakt definition)

En CIC per kanal: ordning **N = 4**, decimering **R = 32**, differentiell fördröjning M = 1.

- Ingång: PDM-bit `1` → `+1`, `0` → `-1`.
- Fyra integratorer i följd, uppdateras en gång per ingående bit (på kanalens `valid`).
  Integratorerna nollställs vid reset. Bit `x[n]` räknas med i integratorernas utvärde `y[n]`.
- Decimering: var 32:a integratorvärde tas, `d[k] = y[32*k + 31]`, k = 0, 1, ...
  Räknaren startar vid reset, så första utvärdet kommer efter 32 ingående bitar.
- Fyra kammar i följd: `c[k] = d[k] - d[k-1]`, med `d[-1] = 0` (fördröjningsregistren nollställs vid reset).
- Registerbredd: 22 bitar tvåkomplement (2 + 4*log2(32)). Integratorerna får slå runt,
  slutresultatet blir ändå exakt eftersom det ryms i 22 bitar.
- Utgång: `out = mättning(c >> 5, -32768, 32767)` som int16. `>>` är aritmetisk skift
  (avrundning nedåt). Max |c| är 32^4 = 2^20, så bara +2^20 mättas (till 32767).
- Förstärkningen vid DC är alltså 1: en ström med bara ettor ger 32767, bara nollor -32768.

Känd begränsning: vid 40 kHz dämpar CIC:en ca 10 dB (droop), och signaler kring
57,6 kHz viks ner mot 40 kHz med bara ca 13 dB dämpning relativt 40 kHz. Python-modellen
visar om det räcker. Annars: CIC ÷16 + FIR ÷2.

## 4. Sändpuls (chirp)

- Linjär chirp **38 → 42 kHz**, längd **1 ms** (100 000 systemcykler).
- Fyrkantsvåg från en fasackumulator: `tx_p` = fasens MSB, `tx_n = not tx_p` under pulsen.
  Båda är `0` när ingen puls skickas. Drivaren (TC4427A, dubbel) driver givaren
  differentiellt med dem.
- Startar på `chirp_start` (puls en systemcykel) från `capture_spi`.

## 5. Inspelning

- `capture_spi` tar emot 16 sampel samtidigt (`samples`, typ `sample_array` i
  `mic_array_pkg`) med en `sample_valid`-puls per utsampel (97,66 kHz). Värdena är
  stabila mellan pulserna.
- Vid PING: `chirp_start` samma cykel, sedan skrivs de `N_SAMPLES` nästa utsamplen till BRAM.
  Adress = `sampel * 16 + kanal`, 16 bitar per ord.
- Fördröjningen från chirpstart till sampel 0 (plus CIC:ens gruppfördröjning) är konstant.
  Den mäts i simuleringen av hela kedjan (`fpga/sim/run_e2e.sh`): 0,3-1,3 sampel beroende på
  var i decimeringsperioden PINGen kommer. **`LATENCY_SAMPLES = 0.8`** (±0,9 mm i avstånd),
  i `software/sonar/protocol.py`.

## 6. SPI-protokoll (Pi är master)

- Läge 0 (CPOL = 0, CPHA = 0), MSB först, `spi_cs_n` aktiv låg, **SCLK högst 8 MHz**
  (FPGA:n översamplar SCLK med 100 MHz; MISO kommer upp till ca 40 ns efter fallande flank,
  inklusive utgångsbufferten). Simuleringen kör 10 MHz. Börja på 1-4 MHz vid första testet.
- Sätt ett serieresistor på 33-100 Ω i SCLK nära Pi:n. FPGA:n har inget glitchfilter, så
  ringningar på en lång kabel kan räknas som en extra flank och förskjuta alla bitar.
- Varje transaktion (CS låg → CS hög) börjar med en kommandobyte från mastern.
- `spi_miso` är hög-Z när `spi_cs_n` är hög.

| Kommando | Mastern skickar | FPGA:n svarar |
|---|---|---|
| `0x01` STATUS | `01 00` | Byte 2: status (se nedan) |
| `0x02` PING | `02` | inget. Ignoreras om inte `READY`. |
| `0x03` READ | `03 AH AL 00` + 2·n nollbytes | Från byte 5: n ord à 16 bitar, big-endian, från ordadress `AH:AL` och framåt. |

Statusbyte:

| Bit | Namn | Betydelse |
|---|---|---|
| 7-4 | ID | Alltid `0xA`. Fel värde = fel koppling. |
| 3 | PING_TOGGLE | Växlar vid varje godkänd PING. Pi:n jämför före och efter, så att en förlorad PING inte ger förra inspelningen igen. |
| 2 | DATA_VALID | En inspelning är klar och ligger i minnet (nollas vid nästa PING) |
| 1 | CAPTURING | Spelar in |
| 0 | READY | Ultraljudsläge, minst `SETTLE_CYCLES` sedan bytet, och spelar inte in |

Ordadressen är 16 bitar (0..65535), så hela minnet (16 · 2048 = 32 768 ord) nås.
Pi:n läser i bitar om t.ex. 1024 ord per transaktion, så att spidevs standardbuffert
(4096 byte) räcker.

## 7. Pinnar (Boolean Board, PMOD)

Pinnarna är utlästa ur schemat i Boolean-manualen (rev. från realdigital.org) och
**ska verifieras** mot manualen innan kortet kopplas in. Alla LVCMOS33.

| Signal | Port | PMOD-nät | FPGA-pinne |
|---|---|---|---|
| `pdm_data[0..7]` | JA | JA1_P, JA1_N, JA2_P, JA2_N, JA3_P, JA3_N, JA4_P, JA4_N | B13, A13, B14, A14, E12, D12, C13, C14 |
| `mic_clk` | JB | JB1_P | B15 |
| `tx_p`, `tx_n` | JB | JB1_N, JB2_P | A15, B17 |
| `spi_sclk`, `spi_mosi`, `spi_miso`, `spi_cs_n` | JC | JC1_P, JC1_N, JC2_P, JC2_N | T6, T5, R5, T4 |

På Pi:n: SPI0, `SCLK` GPIO11, `MOSI` GPIO10, `MISO` GPIO9, `CE0` GPIO8. Gemensam jord.
