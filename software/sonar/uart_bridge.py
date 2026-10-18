"""UART->SPI-brygga mot FPGA:n (FT2232 kanal B). Har spidevs `xfer2`, så
`SonarDevice(UartSpi("/dev/ttyUSB1"))` fungerar som mot en riktig SPI-buss.

Ramning: 2 byte längd L (big-endian), L byte data; bryggan gör en SPI-transaktion
och svarar med exakt L MISO-byte.
"""

import os
import select
import termios
import time


class UartSpi:
    def __init__(self, port: str, baud: int = 2_000_000, timeout: float = 1.0):
        self.timeout = timeout
        speed = getattr(termios, f"B{baud}")
        self.fd = os.open(port, os.O_RDWR | os.O_NOCTTY | os.O_NONBLOCK)
        try:
            attr = termios.tcgetattr(self.fd)
            attr[0] = 0  # iflag
            attr[1] = 0  # oflag
            attr[2] = termios.CS8 | termios.CREAD | termios.CLOCAL  # 8N1, ingen flödeskontroll
            attr[3] = 0  # lflag: rå, ingen echo
            attr[4] = attr[5] = speed
            attr[6][termios.VMIN], attr[6][termios.VTIME] = 0, 0
            termios.tcsetattr(self.fd, termios.TCSANOW, attr)
            termios.tcflush(self.fd, termios.TCIOFLUSH)
        except BaseException:
            os.close(self.fd)
            raise

    def _deadline_wait(self, readable: bool, end: float) -> None:
        left = end - time.monotonic()
        if left <= 0:
            raise IOError(f"timeout ({self.timeout} s) mot UART-bryggan")
        r, w = ([self.fd], []) if readable else ([], [self.fd])
        select.select(r, w, [], left)

    def xfer2(self, tx) -> list[int]:
        n = len(tx)
        if not 1 <= n <= 0xFFFF:
            raise ValueError(f"längd utanför 1..65535: {n}")
        end = time.monotonic() + self.timeout
        buf = memoryview(bytes([n >> 8, n & 0xFF]) + bytes(tx))
        while buf:
            self._deadline_wait(False, end)
            try:
                buf = buf[os.write(self.fd, buf):]
            except BlockingIOError:
                pass
        out = bytearray()
        while len(out) < n:
            self._deadline_wait(True, end)
            try:
                out += os.read(self.fd, n - len(out))
            except BlockingIOError:
                pass
        return list(out)

    def close(self) -> None:
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
