"""Bounded local node-disk parsing; a reserve is not a full-run capacity guarantee."""
RESERVE_BYTES=2*1024**3


def available_bytes(output):
    lines=output.strip().splitlines()
    if len(lines)!=2:raise ValueError('Unrecognized node filesystem observation')
    columns=lines[1].split()
    if len(columns)!=6 or not columns[3].isdigit():raise ValueError('Unrecognized node filesystem observation')
    return int(columns[3])*1024


def require(output):
    available=available_bytes(output)
    if available<RESERVE_BYTES:raise RuntimeError('Node disk reserve below 2 GiB; preserve existing data and free space explicitly before continuing')
    return available
