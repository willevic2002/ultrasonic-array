"""Matchat filter mot sändchirpen (docs/pipeline.md §4) och avståndsuppskattning."""

import numpy as np


def chirp_reference(fs: float, f0: float = 38e3, f1: float = 42e3, length: float = 1e-3) -> np.ndarray:
    """Linjär chirp f0 -> f1 som sinus (ej fyrkant), `length` sekunder."""
    t = np.arange(round(length * fs)) / fs
    return np.sin(2 * np.pi * (f0 * t + (f1 - f0) / (2 * length) * t**2))


def pulse_compress(signals, fs: float, f0: float = 38e3, f1: float = 42e3, length: float = 1e-3) -> np.ndarray:
    """Envelopen |analytiskt matchat filter| per rad. Chirp som börjar vid sampel k ger topp vid k."""
    x = np.atleast_2d(np.asarray(signals, dtype=float))
    ref = chirp_reference(fs, f0, f1, length)
    nfft = 1 << int(np.ceil(np.log2(x.shape[1] + len(ref))))
    spec = np.fft.fft(x, nfft, axis=1) * np.conj(np.fft.fft(ref, nfft))
    h = np.zeros(nfft)  # analytisk signal: behåll positiva frekvenser
    h[0] = h[nfft // 2] = 1
    h[1 : nfft // 2] = 2
    return np.abs(np.fft.ifft(spec * h, axis=1))[:, : x.shape[1]]


def echo_range(envelope, fs: float, latency_samples: float = 0, c: float = 343.0, min_range: float = 0.2) -> float:
    """Avstånd [m] till starkaste ekot. Tur och retur, sändaren i arrayens mitt.
    Allt närmare än min_range hoppas över (direktkoppling)."""
    env = np.asarray(envelope)
    first = int(np.ceil(latency_samples + 2 * min_range / c * fs))
    if first >= len(env):
        raise ValueError("min_range ligger utanför inspelningen")
    k = first + int(np.argmax(env[first:]))
    return (k - latency_samples) / fs * c / 2
