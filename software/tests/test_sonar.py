import numpy as np
import pytest

from sonar import protocol as p
from sonar.device import SonarDevice
from sonar.fake import FakeFpga
from sonar.matched import chirp_reference, echo_range, pulse_compress

FS = p.FS


def rand_data(n, seed=1):
    return np.random.default_rng(seed).integers(-32768, 32768, (16, n), dtype=np.int16)


def test_status_parse():
    assert p.parse_status(0xA5) == (True, False, True, False)
    assert p.parse_status(0xAA) == (False, True, False, True)
    with pytest.raises(ValueError):
        p.parse_status(0x05)
    with pytest.raises(ValueError):
        SonarDevice(type("Z", (), {"xfer2": lambda s, tx: [0] * len(tx)})()).status()


def test_read_request_bytes():
    assert p.read_request(0x1234, 2) == [3, 0x12, 0x34, 0, 0, 0, 0, 0]


@pytest.mark.parametrize("n,chunk", [(2048, 1024), (2048, 2046), (100, 1024), (37, 5), (2048, 1)])
def test_capture_roundtrip(n, chunk):
    if chunk == 1 and n == 2048:
        n = 8  # 1 ord per transaktion är långsamt men korrekt
    data = rand_data(n)
    calls = []
    fpga = FakeFpga(data)
    spi = type("Spy", (), {"xfer2": lambda s, tx: (calls.append(len(tx)), fpga.xfer2(tx))[1]})()
    out = SonarDevice(spi).read_capture(n, chunk)
    assert out.dtype == np.int16 and np.array_equal(out, data)
    assert max(calls) <= 4096


def test_capture_full_path():
    data = rand_data(2048)
    assert np.array_equal(SonarDevice(FakeFpga(data)).capture(timeout=0.1), data)


def test_ping_ignored_when_not_ready():
    fpga = FakeFpga(rand_data(16), ready=False)
    dev = SonarDevice(fpga)
    dev.ping()
    assert not dev.status().data_valid
    with pytest.raises(TimeoutError):
        dev.wait_ready(0.05)
    with pytest.raises(TimeoutError):
        dev.capture(0.05, 16)


def test_fake_header_is_zero():
    rx = FakeFpga(rand_data(16)).xfer2(p.read_request(0, 3))
    assert rx[:4] == [0, 0, 0, 0]


def test_matched_filter_peak():
    ref = chirp_reference(FS)
    rng = np.random.default_rng(0)
    for k in (0, 300, 1500):
        x = rng.normal(0, 0.5, (4, 2048))
        x[:, k : k + len(ref)] += ref
        assert np.all(np.abs(pulse_compress(x, FS).argmax(axis=1) - k) <= 1)


def test_echo_range():
    ref = chirp_reference(FS)
    k = round(2 * 1.0 / 343.0 * FS)
    x = np.random.default_rng(0).normal(0, 0.3, 2048)
    x[:150] += 20  # direktkoppling i närzonen
    x[k : k + len(ref)] += ref
    assert echo_range(pulse_compress(x, FS)[0], FS) == pytest.approx(1.0, abs=0.02)


def test_lost_ping_raises():
    from sonar.device import SonarDevice
    from sonar.fake import FakeFpga

    fpga = FakeFpga(np.zeros((16, 8), dtype=np.int16))
    real = fpga.xfer2
    fpga.xfer2 = lambda tx: [0] * len(tx) if list(tx)[:1] == [0x02] else real(tx)  # PING tappas
    with pytest.raises(IOError, match="PING"):
        SonarDevice(fpga).capture(n_samples=8)
