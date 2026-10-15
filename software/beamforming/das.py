"""Delay-and-sum-beamforming offline.

Fokuserar på punkter i rummet i stället för bara riktningar. Arrayen är
ca 84 mm bred, så fjärrfältet (2*D^2/lambda) börjar först runt 1,6 m vid
40 kHz. Hinder nära roboten ligger alltså i närfältet. Välj en stor radie
för att få ett vanligt fjärrfältsbeteende.

Koordinater: arrayen ligger i xy-planet och tittar längs +z. Allt i meter.
"""

import numpy as np


def speed_of_sound(temp_c: float = 20.0) -> float:
    """Ljudhastighet i torr luft [m/s]. Linjär approximation, bra för ca -20..40 °C."""
    return 331.3 + 0.606 * temp_c


def steering_points(azimuth_deg, elevation_deg, range_m: float) -> np.ndarray:
    """Fokuspunkter (len(az)*len(el), 3) på radien range_m. Ordning: az yttre, el inre."""
    az, el = np.meshgrid(np.radians(azimuth_deg), np.radians(elevation_deg), indexing="ij")
    x = range_m * np.cos(el) * np.sin(az)
    y = range_m * np.sin(el)
    z = range_m * np.cos(el) * np.cos(az)
    return np.stack([x, y, z], axis=-1).reshape(-1, 3)


def delay_and_sum(signals, fs: float, mic_pos, points, c: float = 343.0, band=None) -> np.ndarray:
    """Energi i den fokuserade summasignalen för varje punkt.

    signals: (n_mics, n_samples) decimerad data
    mic_pos: (n_mics, 3) mikrofonpositioner [m]
    points:  (n_points, 3) fokuspunkter [m]
    band:    (f_lo, f_hi) [Hz] för att bara summera t.ex. 35-45 kHz, eller None

    Fraktionella fördröjningar görs i frekvensdomänen. Signalen nollpaddas till
    dubbel längd så att fördröjningen inte viker runt.
    """
    signals = np.asarray(signals, dtype=float)
    mic_pos = np.asarray(mic_pos, dtype=float)
    points = np.asarray(points, dtype=float)
    n_mics, n = signals.shape
    if mic_pos.shape != (n_mics, 3):
        raise ValueError(f"mic_pos har form {mic_pos.shape}, väntade ({n_mics}, 3)")

    spec = np.fft.rfft(signals, n=2 * n, axis=1)
    freqs = np.fft.rfftfreq(2 * n, 1 / fs)
    if band is not None:
        keep = (freqs >= band[0]) & (freqs <= band[1])
        spec, freqs = spec[:, keep], freqs[keep]

    dist = np.linalg.norm(points[:, None, :] - mic_pos[None, :, :], axis=-1)  # (n_points, n_mics)
    delays = (dist - dist.min(axis=1, keepdims=True)) / c

    energy = np.empty(len(points))
    for i, tau in enumerate(delays):
        # Flytta varje kanal tau[m] tidigare så att ekot från punkten hamnar i fas.
        beam = (spec * np.exp(2j * np.pi * freqs[None, :] * tau[:, None])).sum(axis=0)
        energy[i] = np.sum(np.abs(beam) ** 2)
    return energy
