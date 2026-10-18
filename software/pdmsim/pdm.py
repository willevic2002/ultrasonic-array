"""PDM-modulator (andra ordningens sigma-delta) som stand-in för mikrofonen."""

import numpy as np


def pdm_modulate(x):
    """x i [-1, 1] -> uint8 0/1, samma form. 2-D: en rad per kanal.

    Boser-Wooley, två integratorer med förstärkning 0,5 och 1-bitskvantiserare.
    Stabilt för |x| <~ 0,7 (mäts i test_pdmsim); håll signalen under det.
    """
    x = np.asarray(x, dtype=float)
    flat = x.reshape(-1, x.shape[-1])
    bits = np.empty(flat.shape, dtype=np.uint8)
    i1 = np.zeros(len(flat))
    i2 = np.zeros(len(flat))
    for n in range(flat.shape[1]):  # tidsloop, vektoriserad över kanaler
        v = np.where(i2 >= 0, 1.0, -1.0)
        i1 += 0.5 * (flat[:, n] - v)
        i2 += 0.5 * (i1 - v)
        bits[:, n] = v > 0
    return bits.reshape(x.shape)
