## Pinnmall för mikrofonarrayen på Boolean Board.
## INGA PINNAR ÄR VALDA ÄN. Hämta pinnamn från Real Digitals master-XDC för
## Boolean Board och expansionskontakternas pinout i manualen ("Expansion Connectors").
## Kopiera även systemklockans rad (100 MHz) därifrån.

## Systemklocka (från Real Digitals XDC)
# set_property -dict { PACKAGE_PIN <pin> IOSTANDARD LVCMOS33 } [get_ports clk]
# create_clock -period 10.000 -name sys_clk [get_ports clk]

## Mikrofonklocka (delad av alla 16 mikrofoner)
# set_property -dict { PACKAGE_PIN <pin> IOSTANDARD LVCMOS33 } [get_ports mic_clk]

## DATA1-8 (två mikrofoner per linje)
# set_property -dict { PACKAGE_PIN <pin> IOSTANDARD LVCMOS33 } [get_ports {pdm_data[0]}]
# ...
# set_property -dict { PACKAGE_PIN <pin> IOSTANDARD LVCMOS33 } [get_ports {pdm_data[7]}]
