from pathlib import Path

import numpy as np
import pytest

from beamforming.das import delay_and_sum, steering_points
from beamforming.io_utils import load_channel_positions
from pdmsim.cic import cic_decimate
from pdmsim.pdm import pdm_modulate
from pdmsim.scene import echo_signals
from pdmsim.vectors import read_bits, read_samples, write_bits, write_samples

CSV = Path(__file__).resolve().parents[2] / "hardware" / "mic_placement.csv"
FS_PDM = 3.125e6
FS = FS_PDM / 32


def naive_cic(bits):
    """Oberoende referens: faltning med boxcar^4 i Python-heltal, sedan decimering."""
    x = [1 if b else -1 for b in bits]
    kern = [1]
    for _ in range(4):  # boxcar(32)^4
        new = [0] * (len(kern) + 31)
        for i, k in enumerate(kern):
            for j in range(32):
                new[i + j] += k
        kern = new
    y = [sum(kern[j] * x[n - j] for j in range(min(n, len(kern) - 1) + 1)) for n in range(len(x))]
    c = [y[32 * k + 31] for k in range(len(x) // 32)]  # boxcar^4 = integratorer + kammar
    return [max(-32768, min(32767, v >> 5)) for v in c]


def test_cic_dc_and_alternating():
    assert (cic_decimate(np.ones(32 * 20, np.uint8))[4:] == 32767).all()
    assert (cic_decimate(np.zeros(32 * 20, np.uint8))[4:] == -32768).all()
    assert (cic_decimate(np.tile([0, 1], 16 * 20).astype(np.uint8))[4:] == 0).all()


def test_cic_matches_naive_reference():
    rng = np.random.default_rng(1)
    bits = rng.integers(0, 2, (2, 32 * 12), dtype=np.uint8)
    out = cic_decimate(bits)
    assert out.dtype == np.int16
    for ch in range(2):
        assert out[ch].tolist() == naive_cic(bits[ch])


def test_vectors_roundtrip(tmp_path):
    rng = np.random.default_rng(2)
    b = rng.integers(0, 2, (16, 50), dtype=np.uint8)
    write_bits(tmp_path / "b.txt", b)
    assert (read_bits(tmp_path / "b.txt") == b).all()
    s = rng.integers(-32768, 32768, (16, 7)).astype(np.int16)
    write_samples(tmp_path / "s.txt", s)
    assert (read_samples(tmp_path / "s.txt") == s).all()


def test_channel_positions_real_csv():
    assert len({tuple(p) for p in load_channel_positions(CSV)}) == 16


def test_end_to_end_direction():
    mics = load_channel_positions(CSV)
    az_t, el_t, rng = 20, -10, 0.6
    src = steering_points([az_t], [el_t], rng)[0]
    # amplitud 0,15 vid 1 m -> ca 0,4 vid 0,6 m, under sigma-deltats stabila gräns
    x = echo_signals(mics, [(src, 0.15)], FS_PDM, 5e-3)
    out = cic_decimate(pdm_modulate(x)).astype(float)
    az, el = np.arange(-40, 41, 2), np.arange(-30, 31, 2)
    e = delay_and_sum(out, FS, mics, steering_points(az, el, rng), band=(37e3, 43e3))
    i, j = np.unravel_index(np.argmax(e), (len(az), len(el)))
    assert abs(az[i] - az_t) <= 4 and abs(el[j] - el_t) <= 4
