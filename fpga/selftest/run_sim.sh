#!/usr/bin/env bash
# Kör selftest-testbänken i xsim. Exit 0 bara om den skriver PASS.
set -euo pipefail
cd "$(dirname "$0")"
source "${VIVADO_SETTINGS:-/tools/Xilinx/2026.1/Vivado/settings64.sh}" >/dev/null
tb=tb_selftest_top
srcdir="$(cd ../src && pwd)"
src=("$srcdir"/*_pkg.vhd)
for f in "$srcdir"/*.vhd; do case "$f" in *_pkg.vhd|*_top.vhd) ;; *) src+=("$f");; esac; done
for f in "$srcdir"/*_top.vhd; do src+=("$f"); done
for f in uart_rx uart_tx pdm_pattern uart_spi_bridge selftest_top; do src+=("$PWD/$f.vhd"); done
dir="../sim/build/$tb"
mkdir -p "$dir"
cd "$dir"
xvhdl --2008 "${src[@]}" "$OLDPWD/$tb.vhd" >xvhdl.log || { tail -20 xvhdl.log; exit 1; }
xelab --debug typical "$tb" -s "$tb" >xelab.log || { tail -20 xelab.log; exit 1; }
xsim "$tb" -R | tee xsim_run.log | grep -E "PASS|FAIL|Failure|Error" || true
grep -q "PASS" xsim_run.log
