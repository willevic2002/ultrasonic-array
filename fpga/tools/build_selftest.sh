#!/usr/bin/env bash
# Som build.sh men för selftest_top (UART-brygga + mönstergenerator). Exit 0 bara om timing uppfylls.
set -euo pipefail
cd "$(dirname "$0")/.."
source "${VIVADO_SETTINGS:-/tools/Xilinx/2026.1/Vivado/settings64.sh}" >/dev/null
mkdir -p build/selftest
vivado -mode batch -nojournal -log build/selftest/vivado.log -source tools/build_selftest.tcl | grep -E "TIMING:|BUILD OK|ERROR|CRITICAL WARNING" || true
grep -q "BUILD OK" build/selftest/vivado.log
