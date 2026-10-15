# Anteckningar

## Varför fokus på punkter i stället för riktningar

Arrayen är ca 84 mm. Fjärrfältet börjar vid ungefär 2·D²/λ = 2 · 0,084² / 0,0086 ≈ 1,6 m
vid 40 kHz. Hinder nära roboten ligger alltså i närfältet, där en ren riktningsmodell
ger fel. `software/beamforming/das.py` fokuserar därför på punkter (riktning + avstånd).

## Datahastighet FPGA → Pi

3,125 MHz PDM / 16 i decimering ≈ 195 kS/s per kanal. 16 kanaler x 16 bit ≈ 50 Mbit/s.
Det utesluter UART och gör SPI eller Ethernet till rimliga kandidater. Lägre
decimerad samplingsfrekvens (t.ex. ~100 kS/s räcker för 40 kHz ± bandbredd) halverar det.
