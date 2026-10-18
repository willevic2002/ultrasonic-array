## Pinnar för selftest_top på Real Digital Boolean Board (xc7s50csga324-1).
## UART mot FTDI (kortets USB), fyra LED:er. Inga PMOD-pinnar används.
## FTDI-namnen är sedda ur kortets master-XDC: VERIFIERA mot manualen.

set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -period 10.000 -name sys_clk [get_ports clk]

set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]

set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports uart_rx] ;# FPGA-ingång från FTDI
set_property -dict { PACKAGE_PIN U11 IOSTANDARD LVCMOS33 } [get_ports uart_tx] ;# FPGA-utgång till FTDI

set_property -dict { PACKAGE_PIN G1 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN G2 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN F1 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN F2 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

set_false_path -from [get_ports uart_rx]
set_false_path -to   [get_ports {uart_tx led[*]}]
