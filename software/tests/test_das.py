from pathlib import Path

import numpy as np
import pytest

from beamforming.das import delay_and_sum, speed_of_sound, steering_points
from beamforming.io_utils import load_mic_positions


def vogel_spiral(n=16, radius=0.035):
    i = np.arange(n)
    r = radius * np.sqrt((i + 0.5) / n)
    theta = i * np.pi * (3 - np.sqrt(5))
    return np.column_stack([r * np.cos(theta), r * np.sin(theta), np.zeros(n)])


def burst(t, f0=40e3, t0=1e-3, length=1e-3):
    """Hann-fönstrad 40 kHz-puls, beräknad analytiskt (oberoende av FFT-metoden)."""
    u = (t - t0) / length
    win = np.where((u >= 0) & (u <= 1), 0.5 - 0.5 * np.cos(2 * np.pi * u), 0.0)
    return win * np.sin(2 * np.pi * f0 * t)


def test_speed_of_sound():
    assert speed_of_sound(20) == pytest.approx(343.4, abs=0.1)


@pytest.mark.parametrize("az_true,el_true,rng", [(20, -10, 1.0), (-36, 24, 0.4)])
def test_finds_source_direction(az_true, el_true, rng):
    fs = 3.125e6 / 16  # PDM-klocka / decimering
    c = speed_of_sound(20)
    mics = vogel_spiral()
    src = steering_points([az_true], [el_true], rng)[0]
    t = np.arange(int(4e-3 * fs)) / fs
    dist = np.linalg.norm(mics - src, axis=1)
    signals = np.stack([burst(t - d / c) for d in dist])

    az = np.arange(-60, 61, 2)
    el = np.arange(-40, 41, 2)
    energy = delay_and_sum(signals, fs, mics, steering_points(az, el, rng), c=c, band=(35e3, 45e3))
    i_az, i_el = np.unravel_index(np.argmax(energy), (len(az), len(el)))
    assert abs(az[i_az] - az_true) <= 4
    assert abs(el[i_el] - el_true) <= 4


def test_load_mic_positions(tmp_path):
    f = tmp_path / "mics.csv"
    f.write_text("ref,x_mm,y_mm\nMIC1,10.0,-5.0\nMIC2,0,20\n")
    pos = load_mic_positions(f)
    assert pos.shape == (2, 3)
    assert pos[0] == pytest.approx([0.010, -0.005, 0.0])


def test_load_channel_positions():
    from beamforming.io_utils import load_channel_positions

    csv = Path(__file__).resolve().parents[2] / "hardware" / "mic_placement.csv"
    pos, ref = load_channel_positions(csv), load_mic_positions(csv)
    # U4 = DATA1 + VDD -> kanal 0, U1 = DATA1 + GND -> kanal 1
    assert np.allclose(pos[0], ref[3]) and np.allclose(pos[1], ref[0])
    assert len({tuple(p) for p in pos}) == 16
