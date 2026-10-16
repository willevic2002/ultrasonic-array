"""Pi-sidans styrning av FPGA:n över SPI. `spi` ska ha spidevs `xfer2`."""

import time

import numpy as np

from . import protocol as p


class SonarDevice:
    def __init__(self, spi):
        self.spi = spi

    def status(self) -> p.Status:
        return p.parse_status(self.spi.xfer2([p.CMD_STATUS, 0])[1])

    def ping(self) -> None:
        self.spi.xfer2([p.CMD_PING])

    def _wait(self, cond, what: str, timeout: float) -> None:
        end = time.monotonic() + timeout
        while True:
            if cond(self.status()):
                return
            if time.monotonic() >= end:
                raise TimeoutError(f"timeout ({timeout} s) i väntan på {what}")
            time.sleep(0.001)

    def wait_ready(self, timeout: float = 1.0) -> None:
        self._wait(lambda s: s.ready, "READY", timeout)

    def read_capture(self, n_samples: int = 2048, chunk_words: int = 1024) -> np.ndarray:
        """Läser n_samples sampel från adress 0. Returnerar (16, n_samples) int16."""
        total = n_samples * p.N_CHANNELS
        if total > 0x10000:
            raise ValueError("n_samples för stort för 16-bitars ordadress")
        if not 1 <= chunk_words <= (4096 - 4) // 2:
            raise ValueError("chunk_words måste ge högst 4096 byte per transaktion")
        parts = []
        for addr in range(0, total, chunk_words):
            n = min(chunk_words, total - addr)
            resp = self.spi.xfer2(p.read_request(addr, n))
            if len(resp) != 4 + 2 * n:
                raise IOError(f"fel svarslängd: {len(resp)} byte, väntade {4 + 2 * n}")
            parts.append(p.words_from_response(resp))
        return p.words_to_signals(np.concatenate(parts), n_samples)

    def capture(self, timeout: float = 1.0, n_samples: int = 2048) -> np.ndarray:
        self.wait_ready(timeout)
        self.ping()
        self._wait(lambda s: s.data_valid, "DATA_VALID", timeout)
        return self.read_capture(n_samples)


def open_spidev(bus: int = 0, device: int = 0, speed_hz: int = 8_000_000) -> SonarDevice:
    import spidev  # bara på Pi:n

    spi = spidev.SpiDev()
    spi.open(bus, device)
    spi.mode = 0
    spi.max_speed_hz = speed_hz
    return SonarDevice(spi)
