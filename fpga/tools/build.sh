#!/usr/bin/env bash
# Syntes, place & route och bitström. Exit 0 bara om timing uppfylls.
set -euo pipefail
cd "$(dirname "$0")/.."
source "${VIVADO_SETTINGS:-/tools/Xilinx/2026.1/Vivado/settings64.sh}" >/dev/null
mkdir -p build
vivado -mode batch -nojournal -log build/vivado.log -source tools/build.tcl | grep -E "TIMING:|BUILD OK|ERROR|CRITICAL WARNING" || true
grep -q "BUILD OK" build/vivado.log
