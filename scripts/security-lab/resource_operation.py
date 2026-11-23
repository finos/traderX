"""Serialize cooperating operations and enforce capacity even with an inherited lock."""
from contextlib import contextmanager
import fcntl
import os
from pathlib import Path
from resource_preflight import require


@contextmanager
def operation_lock(runtime):
    runtime = Path(runtime).resolve()
    runtime.mkdir(parents=True, exist_ok=True)
    path = runtime/'console-run.lock'
    inherited = os.environ.get('TRADERX_LAB_LOCK_FD')
    owned = None
    if inherited:
        fd = int(inherited)
        actual, expected = os.fstat(fd), path.stat()
        if (actual.st_dev, actual.st_ino) != (expected.st_dev, expected.st_ino):
            raise ValueError('Inherited runner lock does not match runtime')
    else:
        owned = path.open('a'); fd = owned.fileno()
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield fd
    finally:
        if owned: owned.close()


@contextmanager
def operation(runtime, mode):
    with operation_lock(runtime):
        yield require(Path(runtime), mode)
