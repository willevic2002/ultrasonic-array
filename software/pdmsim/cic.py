"""Bitexakt modell av cic_decimator (docs/pipeline.md §3)."""

import numpy as np

N, R = 4, 32


def cic_decimate(bits):
    """PDM-bitar (n,) eller (n_ch, n) -> int16 med n // 32 sampel per kanal.

    int64 slår runt först efter ~2^16 bitar; då blir kammarna ändå exakta (modulo 2^64),
    precis som 22-bitarsregistren i FPGA:n.
    """
    y = np.asarray(bits).astype(np.int64) * 2 - 1
    for _ in range(N):
        y = np.cumsum(y, axis=-1)
    d = y[..., R - 1 :: R]
    for _ in range(N):
        d = np.diff(d, axis=-1, prepend=0)
    return np.clip(d >> 5, -32768, 32767).astype(np.int16)
