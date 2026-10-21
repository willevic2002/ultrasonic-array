# Datablad och referenser

Länkar och vad som ska verifieras i varje dokument. Lägg inte in PDF:erna i git
(upphovsrätt). Länka i stället.

| Komponent | Dokument | Verifiera |
|---|---|---|
| Knowles SPH0641LU4H-1 | [Datablad rev B](https://media.digikey.com/pdf/Data%20Sheets/Knowles%20Acoustics%20PDFs/SPH0641LU4H-1.PDF) | Kontrollerat, se nedan. Kvar: land pattern, porthål mot footprint |
| Same Sky CUSA-T75-18-2400-TH | [Datablad](https://sameskydevices.com/product/resource/cusa-t75-18-2400-th.pdf) | Ø12,5 x 9,5 mm, 40 kHz, 110 dB vid 10 V sinus på 30 cm, max 80 Vp-p, räckvidd 0,2-18 m. TC4427A i brygga på 12 V ger ca 10 Vrms grundton. Kvar: pinndelning för footprint |
| Microchip TC4427A | Datablad (Microchip) | Matningsspänning, utgångsström, logiknivå på ingången (3,3 V från FPGA?) |
| Real Digital Boolean Board | [Manual](https://www.realdigital.org/doc/02013cd17602c8af749f00561f88ae21), avsnitt "Expansion Connectors" | Radantal och pinout (2x15?), vilka pinnar som går till FPGA:n, Vdd/GND-placering |
| Real Digital Boolean Board | Master-XDC på produktsidan | Pinnamn för klocka och expansionskontakter |
| Spartan-7 | AMD UG472 (Clocking Resources) | MMCM-inställningar om exakt 3,072 MHz behövs |

## SPH0641LU4H-1, kontrollerade värden (rev B, 2015-04-06)

Obs: SPH0641**LM4H**-1 är en annan artikel. Repot använder LU4H-1.

| Parameter | Värde | Används i |
|---|---|---|
| Pinnar | 1 DATA, 2 SELECT, 3 GND, 4 CLOCK, 5 VDD | `hardware/` |
| Storlek | 3,50 x 2,65 x 0,98 mm, porthål Ø 0,325 mm | footprint |
| VDD | 1,62-3,6 V | |
| SELECT | VDD: data efter stigande flank. GND: efter fallande. Intern pull-down, får inte flyta | `pdm_pair_capture.vhd` |
| tDD (data valid) | 18 / 28 / 40 ns (min/typ/max) | testbänkens `T_DV` |
| tDZ (till hög-Z) | 3-16 ns | |
| Klocka standardläge | 1,024-2,475 MHz | `HALF_PERIOD_START` |
| Klocka ultraljudsläge | 3,072-4,8 MHz | `HALF_PERIOD_RUN` |
| Pulskvot | 40-60 % (≤ 2,4 MHz), 48-52 % (> 2,4 MHz) | |
| Klockans flanktid | max 3 ns | |
| Wake-up Time | max 15 ms | `STARTUP_CYCLES` (20 ms) |
| Mode-Change Time | max 10 ms | kasta data efter bytet |
| Starta inte i ultraljudsläge | | `pdm_clock_gen.vhd` |
