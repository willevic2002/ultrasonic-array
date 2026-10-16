"""SPI-protokollet mot FPGA:n (docs/pipeline.md §6)."""

from typing import NamedTuple

import numpy as np

CMD_STATUS = 0x01
CMD_PING = 0x02
CMD_READ = 0x03

STATUS_ID = 0xA
READY = 0x01
CAPTURING = 0x02
DATA_VALID = 0x04

N_CHANNELS = 16
FS = 3_125_000 / 32  # 97 656,25 Hz


class Status(NamedTuple):
    ready: bool
    capturing: bool
    data_valid: bool


def parse_status(b: int) -> Status:
    """Tolkar statusbyten. ValueError om ID-nibblen inte är 0xA (fel koppling)."""
    if b >> 4 != STATUS_ID:
        raise ValueError(f"fel ID i statusbyte: 0x{b:02X} (väntade 0xA_), kontrollera kopplingen")
    return Status(bool(b & READY), bool(b & CAPTURING), bool(b & DATA_VALID))


def read_request(addr: int, n_words: int) -> list[int]:
    """Bytes att skicka för att läsa n_words ord från ordadress addr."""
    if not 0 <= addr <= 0xFFFF:
        raise ValueError(f"adress utanför 0..65535: {addr}")
    if n_words < 1:
        raise ValueError("n_words måste vara minst 1")
    return [CMD_READ, addr >> 8, addr & 0xFF, 0] + [0] * (2 * n_words)


def words_from_response(resp) -> np.ndarray:
    """Big-endian int16-ord ur svaret, efter de 4 headerbytena."""
    data = np.asarray(resp, dtype=np.uint8)[4:]
    if len(data) % 2:
        raise ValueError("udda antal databytes i svaret")
    return data.view(">i2").astype(np.int16)


def words_to_signals(words, n_samples: int) -> np.ndarray:
    """Ordadress = sampel*16 + kanal -> (16, n_samples)."""
    words = np.asarray(words)
    if words.size != n_samples * N_CHANNELS:
        raise ValueError(f"väntade {n_samples * N_CHANNELS} ord, fick {words.size}")
    return words.reshape(n_samples, N_CHANNELS).T.copy()
