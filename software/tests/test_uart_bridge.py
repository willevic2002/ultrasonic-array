import os
import pty
import threading

import numpy as np
import pytest

from sonar import selftest
from sonar.device import SonarDevice
from sonar.fake import FakeFpga
from sonar.uart_bridge import UartSpi

N = 256
DATA = np.array([[selftest.expected(c)] * N for c in range(16)])


def _readn(fd, n):
    buf = b""
    while len(buf) < n:
        chunk = os.read(fd, n - len(buf))
        if not chunk:
            raise EOFError
        buf += chunk
    return buf


@pytest.fixture
def bridge():
    """(slave-tty, FakeFpga) med en trådad brygga som ramar UART -> FakeFpga.xfer2."""
    master, slave = pty.openpty()
    fpga = FakeFpga(DATA)

    def serve():
        try:
            while True:
                n = int.from_bytes(_readn(master, 2), "big")
                os.write(master, bytes(fpga.xfer2(list(_readn(master, n)))))
        except OSError:  # EOF/EIO när testet stänger
            pass
        except EOFError:
            pass

    threading.Thread(target=serve, daemon=True).start()
    yield os.ttyname(slave), fpga
    os.close(master)
    os.close(slave)


def test_capture_constants_and_selftest_check(bridge):
    with UartSpi(bridge[0], timeout=2.0) as spi:
        sig = SonarDevice(spi).capture(n_samples=N)
    assert (sig == DATA).all()
    assert selftest.check(sig)


def test_corrupted_value_fails(bridge):
    bridge[1].mem[5 * 16 + 3] += 1
    with UartSpi(bridge[0], timeout=2.0) as spi:
        sig = SonarDevice(spi).capture(n_samples=N)
    assert not selftest.check(sig)


def test_silent_bridge_times_out():
    master, slave = pty.openpty()
    with UartSpi(os.ttyname(slave), timeout=0.2) as spi:
        with pytest.raises(IOError):
            spi.xfer2([1, 0])
    os.close(master)
    os.close(slave)


def test_length_validation(bridge):
    with UartSpi(bridge[0]) as spi:
        for bad in ([], [0] * 65536):
            with pytest.raises(ValueError):
                spi.xfer2(bad)
