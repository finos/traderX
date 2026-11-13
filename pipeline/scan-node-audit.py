#!/usr/bin/env python3
"""Audit a locked Node production dependency tree; distinguish findings from outages."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


def classify(report, returncode):
    if (returncode not in (0, 1) or not isinstance(report, dict) or report.get('error')
            or report.get('auditReportVersion') != 2
            or not isinstance(report.get('vulnerabilities'), dict)):
        return 2
    # Conservatively fail on any production finding, including low severity.
    if report['vulnerabilities']:
        return 1
    return 0 if returncode == 0 else 2


def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument('module')
    parser.add_argument('report')
    args = parser.parse_args()
    root = Path(args.module).resolve()
    if not (root / 'package-lock.json').is_file():
        print('[fail] npm audit requires a generated package-lock.json')
        return 2
    try:
        result = subprocess.run(['npm', 'audit', '--omit=dev', '--package-lock-only', '--json'],
                                cwd=root, capture_output=True, text=True)
    except OSError:
        print('[fail] cannot start npm audit')
        return 2
    output = Path(args.report)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(result.stdout)
    try:
        code = classify(json.loads(result.stdout), result.returncode)
    except ValueError:
        code = 2
    print(f'[audit] report={output}; status={ {0: "success", 1: "findings", 2: "infrastructure_failure"}[code]}')
    return code


if __name__ == '__main__':
    sys.exit(main())
