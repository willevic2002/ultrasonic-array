"""Simulering av hela kedjan, Python-delen. Körs av run_e2e.sh.

  e2e.py gen <dir>    skapar e2e_stim.txt: ett eko från en känd punkt, som PDM-bitar
  e2e.py check <dir>  kontrollerar testbänkens utdata:
                      1. inspelningen är bitexakt lika med Python-CIC:en på de bitar som matades in
                      2. matchat filter + delay-and-sum hittar punkten (avstånd och riktning)
                      och skriver ut LATENCY_SAMPLES (docs/pipeline.md §5)
"""

import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "software"))

from beamforming.das import delay_and_sum, steering_points  # noqa: E402
from beamforming.io_utils import load_channel_positions  # noqa: E402
from pdmsim.cic import cic_decimate  # noqa: E402
from pdmsim.pdm import pdm_modulate  # noqa: E402
from pdmsim.scene import echo_signals  # noqa: E402
from pdmsim.vectors import read_bits, read_samples, write_bits  # noqa: E402
from sonar.matched import echo_range, pulse_compress  # noqa: E402

F_BIT = 3.125e6
FS = F_BIT / 32
C = 343.0
N_SAMPLES = 384  # samma som testbänkens generic
AZ, EL, RANGE = 20.0, -10.0, 0.35  # reflektorn
MICS = ROOT / "hardware" / "mic_placement.csv"


def gen(out: Path) -> None:
    pos = load_channel_positions(MICS)
    point = steering_points([AZ], [EL], RANGE)[0]
    duration = (N_SAMPLES + 4) / FS
    # Amplitud 0,06 vid 1 m ger ca 0,5 FS vid 0,35 m. Lite brus så att PDM inte blir periodisk.
    x = echo_signals(pos, [(point, 0.06)], F_BIT, duration, c=C)
    x += np.random.default_rng(1).normal(0, 0.01, x.shape)
    write_bits(out / "e2e_stim.txt", pdm_modulate(x))


def check(out: Path) -> None:
    fed = read_bits(out / "e2e_fed_bits.txt")
    cap = read_samples(out / "e2e_captured.txt")
    start_period = int((out / "e2e_meta.txt").read_text().split()[1])
    assert cap.shape == (16, N_SAMPLES), cap.shape

    ref = cic_decimate(fed)
    offsets = [o for o in range(ref.shape[1] - N_SAMPLES + 1)
               if np.array_equal(ref[:, o:o + N_SAMPLES], cap)]
    assert len(offsets) == 1, f"inspelningen matchar inte Python-CIC:en (träffar: {offsets})"
    offset = offsets[0]
    # Ett impulssvar vid bit b har sin topp i utsampel (b + 62 - 31) / 32 (gruppfördröjning 62 bitar).
    latency = (start_period + 31) / 32 - offset
    print(f"OK bitexakt: {N_SAMPLES} sampel x 16 kanaler, CIC-utsampel {offset}..{offset + N_SAMPLES - 1}")
    print(f"LATENCY_SAMPLES = {latency:.2f}  (chirpstart -> index i inspelningen)")

    signals = cap.astype(float)
    r = echo_range(pulse_compress(signals, FS).sum(axis=0), FS, latency_samples=latency, c=C)
    az = np.arange(-60, 61, 2)
    el = np.arange(-40, 41, 2)
    energy = delay_and_sum(signals, FS, load_channel_positions(MICS),
                           steering_points(az, el, r), c=C, band=(37e3, 43e3))
    i_az, i_el = np.unravel_index(np.argmax(energy), (len(az), len(el)))
    print(f"eko: {r:.3f} m (sant {RANGE}), azimut {az[i_az]}° (sant {AZ:g}), elevation {el[i_el]}° (sant {EL:g})")
    assert abs(r - RANGE) < 0.03, "fel avstånd"
    assert abs(az[i_az] - AZ) <= 4 and abs(el[i_el] - EL) <= 4, "fel riktning"
    print("PASS: hela kedjan")


if __name__ == "__main__":
    {"gen": gen, "check": check}[sys.argv[1]](Path(sys.argv[2]))
