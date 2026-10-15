# Datablad och referenser

Länkar och vad som ska verifieras i varje dokument. Lägg inte in PDF:erna i git
(upphovsrätt). Länka i stället.

| Komponent | Dokument | Verifiera |
|---|---|---|
| Knowles SPH0641LU4H-1 | Datablad (Knowles webbplats) | Pinordning, SELECT ↔ klockflank, tDV, klockintervall per läge, starttid, land pattern, porthål |
| Murata MA40S4S | Datablad (Murata) | Resonansfrekvens, max drivspänning. Not for new designs: hitta ersättare |
| Microchip TC4427A | Datablad (Microchip) | Matningsspänning, utgångsström, logiknivå på ingången (3,3 V från FPGA?) |
| Real Digital Boolean Board | [Manual](https://www.realdigital.org/doc/02013cd17602c8af749f00561f88ae21), avsnitt "Expansion Connectors" | Radantal och pinout (2x15?), vilka pinnar som går till FPGA:n, Vdd/GND-placering |
| Real Digital Boolean Board | Master-XDC på produktsidan | Pinnamn för klocka och expansionskontakter |
| Spartan-7 | AMD UG472 (Clocking Resources) | MMCM-inställningar om exakt 3,072 MHz behövs |
