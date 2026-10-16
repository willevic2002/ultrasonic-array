#!/usr/bin/env bash
# Hela kedjan: Python-scen -> PDM-bitar -> mic_array_top i xsim (via SPI som Pi:n) -> kontroll i Python.
# Exit 0 bara om inspelningen är bitexakt och ekot hittas på rätt avstånd och i rätt riktning.
# Kräver numpy: sätt PYTHON till en python med numpy om systemets saknar det.
set -euo pipefail
cd "$(dirname "$0")"
PY="${PYTHON:-python3}"
dir=build/e2e_mic_array_top
mkdir -p "$dir"
"$PY" e2e.py gen "$dir"
./run_xsim.sh e2e_mic_array_top
"$PY" e2e.py check "$dir"
