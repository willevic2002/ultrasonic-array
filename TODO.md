# TODO

## Hårdvara (steg 3-kortet)

- [ ] Byt platshållar-footprinten för SPH0641LU4H-1 mot riktig footprint
      (DigiKey/SnapEDA/Ultra Librarian eller databladets land pattern)
- [ ] Hål i kortet under varje mikrofons akustiska port (Ø 0,325 mm port, kolla rekommenderad hålstorlek)
- [ ] 0,1 µF C0G/NP0 avkoppling vid varje mikrofons VDD
- [ ] Dra ledningar: 8 DATA, 1 CLK (tänk på längd/stubbar för delad klocka), SELECT till GND/VDD
- [ ] Jordplan
- [ ] DRC
- [ ] Sändare (40 kHz) i mitten + drivare (TC4427A eller liknande) + TX-signal från FPGA
- [ ] Extern 10-12 V-matning till drivaren
- [ ] Välj ersättare för MA40S4S (not for new designs)
- [ ] Kontakt mot Boolean Boards Pmod+/expansionskontakt (verifiera radantal och pinout)
- [ ] Monteringsanvisning: tvätta inte kortet efter lödning (mikrofonportarna)

## FPGA

- [ ] Verifiera Boolean Boards pinnar och välj pinnar för CLK och DATA1-8 ur Real Digitals constraints-fil
- [ ] Verifiera mot databladet: pinordning, SELECT-nivå ↔ klockflank, tDV, klockintervall per läge, starttid
- [ ] Testa `pdm_clock_gen` + `pdm_pair_capture` i hårdvara (en mikrofon, sen ett par)
- [ ] CIC-decimering per kanal (16 kanaler)
- [ ] Skala upp till 8 datalinjer
- [ ] TX: generera chirp/burst till sändaren
- [ ] Exakt 3,072 MHz via MMCM om det behövs (just nu 3,125 MHz)

## Länk FPGA → Pi

- [ ] Beslut: UART, SPI eller Ethernet (16 kanaler x ~195 kS/s x 16 bit ≈ 50 Mbit/s räcker inte på UART)
- [ ] Dataformat (rubrik, kanalordning, tidsstämpel) och uppdatera `software/beamforming/io_utils.py`

## Mjukvara

- [ ] Chirp + matchat filter för avståndsmätning
- [ ] Kör delay-and-sum på riktig mätdata
- [ ] Kalibrering av mikrofonernas faktiska positioner
- [ ] Temperaturkompensation av ljudhastigheten (temperatursensor)
- [ ] ROS 2-nod (på sikt)
