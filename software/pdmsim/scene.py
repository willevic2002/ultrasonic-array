"""Syntetiskt eko: chirp och punktreflektorer, före PDM-modulering."""

import numpy as np


def chirp(t, f0=38e3, f1=42e3, length=1e-3, ramp=0.1):
    """Linjär chirp f0->f1, noll utanför [0, length]. Tukey-ramper (andel `ramp`) mot spektralläckage."""
    t = np.asarray(t, dtype=float)
    u = t / length
    phase = 2 * np.pi * (f0 * t + 0.5 * (f1 - f0) / length * t**2)
    w = np.ones_like(u)
    if ramp > 0:
        r = ramp / 2
        w = np.where(u < r, 0.5 - 0.5 * np.cos(np.pi * u / r), w)
        w = np.where(u > 1 - r, 0.5 - 0.5 * np.cos(np.pi * (1 - u) / r), w)
    return np.where((u >= 0) & (u <= 1), w * np.sin(phase), 0.0)


def echo_signals(mic_pos, reflectors, fs, duration, c=343.0, tx_pos=(0, 0, 0)):
    """(n_mics, n) analogsignal. reflectors: [(punkt, amplitud)].

    Amplitud = toppvärde vid 1 m tur och 1 m retur; skalas med 1/(r_tx*r_rx). t=0 är chirpstart.
    """
    mic_pos = np.asarray(mic_pos, dtype=float)
    tx = np.asarray(tx_pos, dtype=float)
    t = np.arange(int(round(duration * fs))) / fs
    out = np.zeros((len(mic_pos), len(t)))
    for p, amp in reflectors:
        p = np.asarray(p, dtype=float)
        r_tx = np.linalg.norm(p - tx)
        r_rx = np.linalg.norm(mic_pos - p, axis=1)
        for m in range(len(mic_pos)):
            out[m] += amp / (r_tx * r_rx[m]) * chirp(t - (r_tx + r_rx[m]) / c)
    return out
