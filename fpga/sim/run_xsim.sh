#!/usr/bin/env bash
# Kör testbänkar i Vivados simulator (xsim). Exit 0 bara om alla skriver PASS.
#   run_xsim.sh                      alla sim/tb_*.vhd
#   run_xsim.sh tb_pdm_pair_capture  bara en
# Varje testbänk byggs i build/<tb>/. Finns sim/<tb>.wcfg kopieras den dit,
# så att "cd build/<tb> && xsim <tb> -gui" visar rätt signaler direkt.
set -euo pipefail
cd "$(dirname "$0")"
source "${VIVADO_SETTINGS:-/tools/Xilinx/2026.1/Vivado/settings64.sh}" >/dev/null

if [ $# -gt 0 ]; then tbs=("$@"); else tbs=($(ls tb_*.vhd | sed 's/\.vhd$//')); fi

# Ordning: paket, sedan moduler, sist toppnivåer (de instansierar modulerna).
srcdir="$(cd ../src && pwd)"
src=("$srcdir"/*_pkg.vhd)
for f in "$srcdir"/*.vhd; do case "$f" in *_pkg.vhd|*_top.vhd) ;; *) src+=("$f");; esac; done
for f in "$srcdir"/*_top.vhd; do [ -e "$f" ] && src+=("$f"); done

for tb in "${tbs[@]}"; do
  echo "=== $tb"
  mkdir -p "build/$tb"
  [ -e "$tb.wcfg" ] && cp "$tb.wcfg" "build/$tb/"
  (
    cd "build/$tb"
    xvhdl --2008 "${src[@]}" "../../$tb.vhd" >xvhdl.log || { tail -20 xvhdl.log; exit 1; }
    xelab --debug typical "$tb" -s "$tb" >xelab.log || { tail -20 xelab.log; exit 1; }
    xsim "$tb" -R | tee xsim_run.log | grep -E "PASS|FAIL|Failure|Error" || true
    grep -q "PASS" xsim_run.log
  )
done
