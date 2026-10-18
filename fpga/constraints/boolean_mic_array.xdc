## Pinnar för mic_array_top på Real Digital Boolean Board (xc7s50csga324-1).
## Se docs/pipeline.md §7. PMOD-pinnarna är utlästa ur schemat i Boolean-manualen
## (nätnamn JAx_P/N osv.). VERIFIERA mot manualen innan något kopplas in.

## Systemklocka 100 MHz (från Real Digitals master-XDC)
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

## JA: DATA1-8 från mikrofonkortet (två mikrofoner per linje)
set_property -dict { PACKAGE_PIN B13 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[0]}] ;# JA1_P
set_property -dict { PACKAGE_PIN A13 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[1]}] ;# JA1_N
set_property -dict { PACKAGE_PIN B14 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[2]}] ;# JA2_P
set_property -dict { PACKAGE_PIN A14 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[3]}] ;# JA2_N
set_property -dict { PACKAGE_PIN E12 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[4]}] ;# JA3_P
set_property -dict { PACKAGE_PIN D12 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[5]}] ;# JA3_N
set_property -dict { PACKAGE_PIN C13 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[6]}] ;# JA4_P
set_property -dict { PACKAGE_PIN C14 IOSTANDARD LVCMOS33 } [get_ports {pdm_data[7]}] ;# JA4_N

## JB: mikrofonklocka och sändare
set_property -dict { PACKAGE_PIN B15 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports mic_clk] ;# JB1_P, databladet: flank max 3 ns
set_property -dict { PACKAGE_PIN A15 IOSTANDARD LVCMOS33 } [get_ports tx_p] ;# JB1_N
set_property -dict { PACKAGE_PIN B17 IOSTANDARD LVCMOS33 } [get_ports tx_n] ;# JB2_P

## JC: SPI till Raspberry Pi (Pi är master)
set_property -dict { PACKAGE_PIN T6 IOSTANDARD LVCMOS33 } [get_ports spi_sclk] ;# JC1_P
set_property -dict { PACKAGE_PIN T5 IOSTANDARD LVCMOS33 } [get_ports spi_mosi] ;# JC1_N
set_property -dict { PACKAGE_PIN R5 IOSTANDARD LVCMOS33 SLEW FAST } [get_ports spi_miso] ;# JC2_P
set_property -dict { PACKAGE_PIN T4 IOSTANDARD LVCMOS33 PULLUP TRUE } [get_ports spi_cs_n] ;# JC2_N, pull-up: inget händer utan Pi

## Alla in- och utgångar är asynkrona mot sys_clk (synkas med två vippor eller
## är långsamma jämfört med 100 MHz), så de ska inte tidsanalyseras.
set_false_path -from [get_ports {pdm_data[*] spi_sclk spi_mosi spi_cs_n}]
set_false_path -to   [get_ports {mic_clk tx_p tx_n spi_miso}]
