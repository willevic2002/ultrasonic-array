"""Kör delay-and-sum på en loggfil och skriv ut starkaste riktningen.

Exempel (från software/):
    python -m beamforming data.npz --mics ../hardware/mic_placement.csv --range 1.0 --temp 20
"""

import argparse

import numpy as np

from .das import delay_and_sum, speed_of_sound, steering_points
from .io_utils import load_mic_positions, load_raw


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("data", help=".npz eller .csv med rådata")
    p.add_argument("--mics", required=True, help="mic_placement.csv")
    p.add_argument("--fs", type=float, help="samplingsfrekvens, krävs för .csv")
    p.add_argument("--range", type=float, default=1.0, help="fokusavstånd [m]")
    p.add_argument("--temp", type=float, default=20.0, help="lufttemperatur [°C]")
    p.add_argument("--band", type=float, nargs=2, default=(35e3, 45e3), metavar=("F_LO", "F_HI"))
    args = p.parse_args()

    signals, fs = load_raw(args.data, args.fs)
    mic_pos = load_mic_positions(args.mics)
    az = np.arange(-60, 61, 2)
    el = np.arange(-40, 41, 2)
    energy = delay_and_sum(signals, fs, mic_pos, steering_points(az, el, args.range),
                           c=speed_of_sound(args.temp), band=args.band)
    i_az, i_el = np.unravel_index(np.argmax(energy), (len(az), len(el)))
    print(f"starkast: azimut {az[i_az]}°, elevation {el[i_el]}° (fokus {args.range} m)")


if __name__ == "__main__":
    main()
