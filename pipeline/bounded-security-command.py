#!/usr/bin/env python3
"""Run one scanner operation with a deadline and operation-scoped cleanup."""
import argparse
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import time


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('--timeout', type=int, required=True)
    parser.add_argument('--phase', choices=['acquisition', 'scan'], required=True)
    parser.add_argument('--result', required=True)
    parser.add_argument('--container')
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    if args.timeout <= 0 or not args.command:
        parser.error('a positive timeout and command are required')
    command = args.command[1:] if args.command[0] == '--' else args.command
    started = time.monotonic()
    process = None
    rc = None
    status, code = 'infrastructure_failure', 20

    def cancel(signum, frame):
        raise InterruptedError(signum)

    signal.signal(signal.SIGTERM, cancel)
    signal.signal(signal.SIGINT, cancel)
    print(f'[step] security {args.phase}: deadline {args.timeout}s', flush=True)
    try:
        process = subprocess.Popen(command, start_new_session=True)
        rc = process.wait(timeout=args.timeout)
        # Dependency-Check CLI App.determineReturnCode returns 1 for CVSS findings.
        if rc == 0:
            status, code = 'success', 0
        elif rc == 1 and args.phase == 'scan':
            status, code = 'findings', 10
        elif rc < 0 or rc in (130, 143):
            status, code = 'cancelled', 130
    except subprocess.TimeoutExpired:
        status, code = 'timeout', 124
    except InterruptedError:
        status, code = 'cancelled', 130
    except OSError as exc:
        print(f'[fail] cannot start scanner: {exc}', file=sys.stderr)
    finally:
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        if process is not None:
            # Kill only the new session, including descendants of shell launchers.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.wait()
        if args.container:
            try:
                cleanup = subprocess.run(['docker', 'rm', '-f', args.container], timeout=5,
                                         capture_output=True, text=True)
                if cleanup.returncode and 'No such container' not in cleanup.stderr:
                    print(f'[warn] cleanup unconfirmed; inspect container {args.container}', file=sys.stderr)
            except (OSError, subprocess.SubprocessError):
                print(f'[warn] cleanup unconfirmed; inspect container {args.container}', file=sys.stderr)
        result = {'phase': args.phase, 'status': status, 'exit_code': code, 'command_exit_code': rc,
                  'elapsed_seconds': round(time.monotonic() - started, 2)}
        Path(args.result).parent.mkdir(parents=True, exist_ok=True)
        Path(args.result).write_text(json.dumps(result) + '\n')
        print(f'[{"ok" if code == 0 else "fail"}] {args.phase}: {status}; result: {args.result}', flush=True)
        if code:
            print('[hint] Resolve findings or restore scanner/registry access, then rerun. '
                  'Deferring to CI does not grant deployment eligibility.', flush=True)
    return code


if __name__ == '__main__':
    sys.exit(main())
