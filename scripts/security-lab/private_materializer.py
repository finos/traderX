"""Copy selected projected Secret keys into private regular files before exec."""
import argparse
import os
from pathlib import Path
import re
import secrets
import stat

LIMIT = 1024 * 1024


def materialize(source, target, names):
    source = Path(source)
    target = Path(target)
    if not source.is_absolute() or not target.is_absolute() or source.is_symlink() or target.is_symlink():
        raise ValueError('Absolute non-symlink directories required')
    if target.parent.resolve(strict=True) != target.parent:
        raise ValueError('Private parent cannot traverse symlinks')
    source = source.resolve(strict=True)
    if not source.is_dir() or not names or len(names) > 16 or len(set(names)) != len(names):
        raise ValueError('Invalid projected configuration inventory')
    # Kubernetes changes ..data atomically. Resolve it once so a rotation cannot
    # combine files from different projected generations in the same copy.
    projection = (source/'..data').resolve(strict=True) if (source/'..data').is_symlink() else source
    if not projection.is_relative_to(source):
        raise ValueError('Projected generation escaped its mount')
    values = {}
    for name in names:
        if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.-]{0,63}', name):
            raise ValueError('Invalid projected key')
        resolved = (projection/name).resolve(strict=True)
        if not resolved.is_relative_to(projection):
            raise ValueError('Projected key escaped its mount')
        fd = os.open(resolved, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
        with os.fdopen(fd, 'rb') as stream:
            info = os.fstat(stream.fileno())
            if (not stat.S_ISREG(info.st_mode) or info.st_uid not in (0, os.geteuid())
                    or info.st_mode & 0o027 or info.st_size > LIMIT):
                raise ValueError('Unsafe projected configuration')
            value = stream.read(LIMIT+1)
        if len(value) > LIMIT:
            raise ValueError('Projected configuration too large')
        values[name] = value
    # mkdir reserves a destination; a partial failed copy stays unusable. No
    # cleanup of an unknown/replaced directory is ever attempted.
    created = False
    try:
        target.mkdir(mode=0o700)
        created = True
    except FileExistsError:
        pass
    fd = os.open(target, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
        if info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError('Private configuration directory ownership or mode invalid')
        if not created and set(os.listdir(fd)) != set(names):
            raise ValueError('Private configuration incomplete or unexpected')
        for name, value in values.items():
            if created:
                pending='.pending-'+secrets.token_hex(16)
                out = os.open(pending, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=fd)
                try:
                    with os.fdopen(out, 'wb') as stream:
                        os.fchmod(stream.fileno(),0o600)
                        stream.write(value); stream.flush(); os.fsync(stream.fileno())
                    # link publishes the completed bytes atomically and refuses
                    # an existing destination; rename/replace would overwrite.
                    os.link(pending,name,src_dir_fd=fd,dst_dir_fd=fd,follow_symlinks=False)
                finally:
                    os.unlink(pending,dir_fd=fd)
            else:
                inp = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
                with os.fdopen(inp, 'rb') as stream:
                    item = os.fstat(stream.fileno())
                    if (not stat.S_ISREG(item.st_mode) or item.st_uid != os.geteuid()
                            or stat.S_IMODE(item.st_mode) != 0o600 or item.st_nlink != 1
                            or stream.read(LIMIT+1) != value):
                        raise ValueError('Private configuration changed; create a fresh pod')
        os.fsync(fd)
    finally:
        os.close(fd)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',required=True,type=Path)
    parser.add_argument('--target',required=True,type=Path)
    parser.add_argument('--key',required=True,action='append')
    parser.add_argument('command',nargs=argparse.REMAINDER)
    args=parser.parse_args()
    argv=args.command[1:] if args.command[:1]==['--'] else args.command
    if not argv or not Path(argv[0]).is_absolute():parser.error('Absolute executable required after --')
    try:materialize(args.source,args.target,args.key)
    except (OSError,ValueError):parser.exit(1,'Private configuration refused; no secret values exported.\n')
    os.execv(argv[0],argv)


if __name__=='__main__':main()
