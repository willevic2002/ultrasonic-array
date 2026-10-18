"""Testvektorfiler för VHDL-testbänkar."""

import numpy as np


def write_bits(path, bits16):
    """(16, n) 0/1 -> en rad per mic_clk-period, tecken i = kanal i."""
    b = np.asarray(bits16)
    assert b.shape[0] == 16
    with open(path, "w") as f:
        f.writelines("".join("1" if v else "0" for v in col) + "\n" for col in b.T)


def read_bits(path):
    with open(path) as f:
        rows = [l.strip() for l in f if l.strip()]
    return np.array([[c == "1" for c in r] for r in rows], dtype=np.uint8).reshape(-1, 16).T


def write_samples(path, samples):
    """(16, n) int -> en rad per utsampel, 16 heltal, kanalordning 0..15."""
    s = np.asarray(samples)
    assert s.shape[0] == 16
    with open(path, "w") as f:
        f.writelines(" ".join(str(int(v)) for v in col) + "\n" for col in s.T)


def read_samples(path):
    return np.loadtxt(path, dtype=np.int64, ndmin=2).T.astype(np.int16)
