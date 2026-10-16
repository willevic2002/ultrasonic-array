# Bygger bitström för selftest_top i non-project mode.
# Kör via fpga/tools/build_selftest.sh. Utdata i fpga/build/selftest/.
set root [file normalize [file dirname [info script]]/..]
set out  $root/build/selftest
file mkdir $out

set src [glob $root/src/*_pkg.vhd]
foreach f [lsort [concat [glob $root/src/*.vhd] [glob $root/selftest/*.vhd]]] {
  if {![string match *_pkg.vhd $f] && ![string match *tb_*.vhd $f]} { lappend src $f }
}
read_vhdl -vhdl2008 $src
read_xdc $root/selftest/selftest.xdc

synth_design -top selftest_top -part xc7s50csga324-1
opt_design
place_design
route_design

report_utilization    -file $out/utilization.rpt
report_timing_summary -file $out/timing.rpt
report_drc            -file $out/drc.rpt

set wns [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -setup]]
set whs [get_property SLACK [get_timing_paths -max_paths 1 -nworst 1 -hold]]
puts "TIMING: WNS=$wns ns WHS=$whs ns"
if {$wns < 0 || $whs < 0} { error "timing uppfylls inte" }

write_bitstream -force $out/selftest.bit
puts "BUILD OK: $out/selftest.bit"
