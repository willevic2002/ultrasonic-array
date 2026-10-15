#!/usr/bin/env bash
# Kör testbänken i Vivados simulator (xsim). Exit 0 bara om testbänken skriver PASS.
set -euo pipefail
cd "$(dirname "$0")"
source "${VIVADO_SETTINGS:-/tools/Xilinx/2026.1/Vivado/settings64.sh}"
mkdir -p build && cd build
xvhdl --2008 ../../src/pdm_clock_gen.vhd ../../src/pdm_pair_capture.vhd ../tb_pdm_pair_capture.vhd
xelab --debug typical tb_pdm_pair_capture -s tb
xsim tb -R | tee xsim_run.log
grep -q "PASS" xsim_run.log
