# Anteckningar

## Synfält: en kupol framåt, inte ett klot

Målet är samma typ av enhet som Sonairs ADAR: ett platt kort som ser i 3D
(riktning i sidled och höjdled + avstånd) inom en kupol framför sig.

- Ett platt kort kan inte se bakåt. Med alla mikrofoner i ett plan ger en punkt
  framför kortet och dess spegelbild bakom kortet samma fördröjningar. Dessutom
  skuggar kortet, och sändaren lyser bara framåt.
- Upplösningen blir sämre mot kupolens kant (ljud som kommer nästan parallellt med kortet).
- Montering: fram på roboten, pekande framåt och ganska lågt, så att kupolen
  når golvet framför roboten (små hinder på marken).
- 360° runt roboten: flera kort som pekar åt olika håll. Varje kort behöver 9
  signaler (CLK + DATA1-8), och FPGA-design och kontakt bör på sikt klara flera kort.

## Varför fokus på punkter i stället för riktningar

Arrayen är ca 84 mm. Fjärrfältet börjar vid ungefär 2·D²/λ = 2 · 0,084² / 0,0086 ≈ 1,6 m
vid 40 kHz. Hinder nära roboten ligger alltså i närfältet, där en ren riktningsmodell
ger fel. `software/beamforming/das.py` fokuserar därför på punkter (riktning + avstånd).

## Datahastighet FPGA → Pi

3,125 MHz PDM / 16 i decimering ≈ 195 kS/s per kanal. 16 kanaler x 16 bit ≈ 50 Mbit/s.
Det utesluter UART och gör SPI eller Ethernet till rimliga kandidater. Lägre
decimerad samplingsfrekvens (t.ex. ~100 kS/s räcker för 40 kHz ± bandbredd) halverar det.
