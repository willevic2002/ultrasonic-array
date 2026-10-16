"""Minnesmodell av FPGA-sidan av SPI-protokollet (docs/pipeline.md §6)."""

import numpy as np

from . import protocol as p


class FakeFpga:
    """Har spidevs `xfer2`. `ready` kan sättas fritt; `data` är (16, n) int16 som
    "spelas in" vid PING."""

    def __init__(self, data=None, ready: bool = True):
        self.ready = ready
        self.capturing = False
        self.data_valid = False
        self.ping_toggle = False
        self.mem = np.zeros(1 << 16, dtype=np.int16)
        if data is not None:
            self.set_data(data)

    def set_data(self, data) -> None:
        data = np.asarray(data, dtype=np.int16)
        if data.ndim != 2 or data.shape[0] != p.N_CHANNELS or data.size > self.mem.size:
            raise ValueError(f"data ska vara (16, n) med n*16 <= 65536, fick {data.shape}")
        self.mem[:] = 0
        self.mem[: data.size] = data.T.reshape(-1)

    def xfer2(self, tx) -> list[int]:
        tx = list(tx)
        rx = [0] * len(tx)
        cmd = tx[0] if tx else None
        if cmd == p.CMD_STATUS:
            if len(tx) > 1:
                rx[1] = (p.STATUS_ID << 4) | (p.READY * self.ready) | (p.CAPTURING * self.capturing) | (
                    p.DATA_VALID * self.data_valid) | (p.PING_TOGGLE * self.ping_toggle
                )
        elif cmd == p.CMD_PING:
            if self.ready and not self.capturing:
                self.data_valid = True  # inspelningen är klar direkt
                self.ping_toggle = not self.ping_toggle
        elif cmd == p.CMD_READ and len(tx) >= 4:
            addr = (tx[1] << 8) | tx[2]
            for i in range((len(tx) - 4) // 2):
                w = int(self.mem[(addr + i) & 0xFFFF]) & 0xFFFF
                rx[4 + 2 * i], rx[5 + 2 * i] = w >> 8, w & 0xFF
        return rx
