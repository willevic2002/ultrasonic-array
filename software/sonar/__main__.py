"""Ta N pings, spara rådata och skriv ut avstånd till starkaste ekot.

Exempel (från software/):
    python -m sonar --fake --pings 1 --out /tmp/x.npz
    python -m sonar --pings 5 --out ping.npz        # på Pi:n
"""

import argparse

import numpy as np

from .device import SonarDevice, open_spidev
from .fake import FakeFpga
from .matched import chirp_reference, echo_range, pulse_compress
from .protocol import FS


def fake_device(n_samples: int, distance: float = 1.0) -> SonarDevice:
    rng = np.random.default_rng(0)
    data = rng.normal(0, 200, (16, n_samples))
    ref = chirp_reference(FS)
    k = round(2 * distance / 343.0 * FS)
    data[:, k : k + len(ref)] += 8000 * ref
    return SonarDevice(FakeFpga(data.round()))


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--pings", type=int, default=1)
    ap.add_argument("--out", required=True, help=".npz-fil (signals, fs)")
    ap.add_argument("--fake", action="store_true", help="syntetisk FPGA, ingen hårdvara")
    ap.add_argument("--speed", type=int, default=8_000_000, help="SPI-klocka [Hz], högst 10 MHz")
    ap.add_argument("--samples", type=int, default=2048)
    a = ap.parse_args()

    dev = fake_device(a.samples) if a.fake else open_spidev(speed_hz=a.speed)
    caps = []
    for i in range(a.pings):
        sig = dev.capture(n_samples=a.samples)
        caps.append(sig)
        r = echo_range(pulse_compress(sig, FS).sum(axis=0), FS)
        print(f"ping {i}: starkaste eko på {r:.3f} m")
    # signals = sista pingen (mic, sampel) så att load_raw fungerar; pings = alla (ping, mic, sampel)
    np.savez(a.out, signals=caps[-1], pings=np.stack(caps), fs=FS)
    print(f"sparade {a.out}")


if __name__ == "__main__":
    main()
