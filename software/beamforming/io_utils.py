"""Inläsning av loggad rådata och mikrofonpositioner.

Dataformatet från FPGA/Pi är inte bestämt än (se TODO.md). Det här är ett
förslag. Ändra här när formatet är spikat.
"""

from pathlib import Path

import numpy as np


def load_raw(path, fs: float | None = None):
    """Returnerar (signals, fs) med signals i formen (n_mics, n_samples).

    .npz: arrayerna 'signals' (n_mics, n_samples) och 'fs'.
    .csv: en kolumn per mikrofon, en rad per sampel, utan rubrik. fs måste anges.
    """
    path = Path(path)
    if path.suffix == ".npz":
        with np.load(path) as data:
            return data["signals"].astype(float), float(data["fs"])
    if path.suffix == ".csv":
        if fs is None:
            raise ValueError("fs måste anges för .csv")
        return np.loadtxt(path, delimiter=",", ndmin=2).T, float(fs)
    raise ValueError(f"okänt filformat: {path.suffix}")


def load_mic_positions(path) -> np.ndarray:
    """Läser mic_placement.csv och returnerar (n_mics, 3) i meter, z = 0.

    Antar en rubrikrad med kolumner vars namn börjar på 'x' och 'y' (t.ex.
    x_mm, y_mm), i millimeter. Anpassa om din fil ser annorlunda ut.
    """
    data = np.genfromtxt(path, delimiter=",", names=True, dtype=None, encoding="utf-8")
    names = data.dtype.names
    try:
        x_col = next(n for n in names if n.lower().startswith("x"))
        y_col = next(n for n in names if n.lower().startswith("y"))
    except StopIteration:
        raise ValueError(f"hittar inga x/y-kolumner i {path}, kolumner: {names}") from None
    xy = np.column_stack([data[x_col], data[y_col]]).astype(float) / 1000.0
    return np.column_stack([xy, np.zeros(len(xy))])
