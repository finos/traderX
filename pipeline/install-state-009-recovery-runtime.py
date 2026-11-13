#!/usr/bin/env python3
"""Compatibility entrypoint; canonical runtime policy now serves every state."""
import runpy
import sys
from pathlib import Path

module = runpy.run_path(str(Path(__file__).with_name('install-runtime-image-policy.py')))
module['install']('009-order-management-matcher', Path(sys.argv[1]))
