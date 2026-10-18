"""Självtest av FPGA:n över UART-bryggan (selftest-bitströmmen, inga mikrofoner).

Varje sampel i kanal c ska vara exakt 2048*(c-8).

    python -m sonar.selftest [/dev/ttyUSB1] [--pings 3] [--samples 2048]
"""

import argparse
import sys
import time

import numpy as np

from .device import SonarDevice
from .protocol import N_CHANNELS
from .uart_bridge import UartSpi


def expected(c: int) -> int:
    return 2048 * (c - 8)


def check(sig: np.ndarray) -> bool:
    """Skriver en tabell per kanal och returnerar True om alla sampel stämmer."""
    ok = True
    first = []
    print(" ch  expected     min     max  mismatches")
    for c in range(N_CHANNELS):
        bad = np.flatnonzero(sig[c] != expected(c))
        ok &= bad.size == 0
        first += [(c, int(i), int(sig[c, i])) for i in bad[:3]]
        print(f"{c:3d} {expected(c):9d} {sig[c].min():7d} {sig[c].max():7d} {bad.size:11d}")
    for c, i, v in first[:8]:
        print(f"  mismatch: ch{c} sampel {i} = {v}, väntade {expected(c)}")
    return ok


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("port", nargs="?", default="/dev/ttyUSB1")
    ap.add_argument("--pings", type=int, default=3)
    ap.add_argument("--samples", type=int, default=2048)
    a = ap.parse_args(argv)
    try:
        spi = UartSpi(a.port)
    except OSError as e:
        print(f"FAIL: kan inte öppna {a.port}: {e}. Prova den andra ttyUSB-porten (ttyUSB0/ttyUSB1).")
        return 1
    with spi:
        dev = SonarDevice(spi)
        try:
            print(f"status (rå): 0x{spi.xfer2([1, 0])[1]:02X}")
            dev.wait_ready(1.0)
            ok = True
            for i in range(a.pings):
                t = time.monotonic()
                sig = dev.capture(n_samples=a.samples)
                dt = time.monotonic() - t
                kb = sig.size * 2 / 1000
                print(f"ping {i}: {dt * 1000:.0f} ms inkl. handskakning, {kb / dt:.0f} kB/s")
                ok &= check(sig)
        except (ValueError, IOError, TimeoutError) as e:
            print(f"FAIL: {e}. Fel ID/ingen respons? Prova den andra ttyUSB-porten.")
            return 1
    print("PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
