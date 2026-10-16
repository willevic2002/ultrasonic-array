# Bygger bitström för mic_array_top i non-project mode.
# Kör via fpga/tools/build.sh. Utdata i fpga/build/.
set root [file normalize [file dirname [info script]]/..]
set out  $root/build
file mkdir $out

set src [glob $root/src/*_pkg.vhd]
foreach f [lsort [glob $root/src/*.vhd]] {
  if {![string match *_pkg.vhd $f]} { lappend src $f }
}
read_vhdl -vhdl2008 $src
read_xdc $root/constraints/boolean_mic_array.xdc

synth_design -top mic_array_top -part xc7s50csga324-1
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

write_bitstream -force $out/mic_array.bit
puts "BUILD OK: $out/mic_array.bit"
