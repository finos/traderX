"""Build one explicit Java security role on the isolated hosted runner."""
import argparse
from pathlib import Path

from build_position_security import SPECS, build


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--role', choices=SPECS, required=True)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    parser.add_argument('--java-home', type=Path, required=True)
    args = parser.parse_args()
    build(args.runtime_dir, args.java_home, role=args.role)
    print(args.role + ': built with verified source, JAR and passing authorization tests.')


if __name__ == '__main__':
    main()
