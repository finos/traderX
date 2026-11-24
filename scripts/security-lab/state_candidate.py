#!/usr/bin/env python3
"""Verified contributor entrypoint for State 019; not a published hardened state."""
import argparse
from pathlib import Path
import subprocess
import sys

import checkpoint
import json
import platform_readiness

SCRIPT=Path(__file__).resolve().with_name('state_lifecycle.py')
RUNTIME_ARGS=('runtime-dir','store','kubeconfig','context','cluster-uid','namespace')


def parser():
    result=argparse.ArgumentParser(description=__doc__)
    commands=result.add_subparsers(dest='action',required=True)
    commands.add_parser('fetch-baseline',help='Explicitly fetch the pinned C3 snapshot')
    for action in ('generate','verify','plan'):
        commands.add_parser(action).add_argument('--checkpoint',type=Path,required=True)
    for action in ('start','test','stop','doctor'):
        command=commands.add_parser(action)
        # Stop must remain possible after a source update or artifact corruption.
        if action!='stop':command.add_argument('--checkpoint',type=Path,required=True)
        for name in RUNTIME_ARGS:command.add_argument('--'+name,required=True)
        if action=='test':command.add_argument('--output',type=Path,required=True)
    return result


def execute(args):
    if args.action=='fetch-baseline':return checkpoint.fetch_baseline()
    if args.action=='generate':return checkpoint.generate(args.checkpoint)
    if args.action!='stop':checkpoint.verify(args.checkpoint)
    if args.action=='verify':return
    if args.action=='doctor':
        result=platform_readiness.inspect(args)
        print(json.dumps(result,indent=2))
        return 0 if result['status']=='ready' else 2
    if args.action=='plan':
        print('Candidate lifecycle only; full hardened-state and fresh-machine acceptance remain pending.')
        print('Prerequisites: reviewed existing cluster/CNI, pinned images, private SQL identity store, explicit cluster UID.')
        print('Start: database/bootstrap → telemetry/collector → trading → nineteen-deployment readiness.')
        print('Test: persistence/restart → settlement/cancellation with independent SQL outcomes.')
        print('Stop: owned collector/workloads down; PVCs and credentials retained. No checkpoint required for recovery stop.')
        print('The offline controls bundle is not a direct kubectl apply target.')
        return
    command=[sys.executable,str(SCRIPT),args.action]
    for name in RUNTIME_ARGS:command.extend(['--'+name,getattr(args,name.replace('-','_'))])
    if args.action=='test':command.extend(['--output',str(args.output)])
    # The lifecycle retains ownership, operation-lock and resource checks.
    subprocess.run(command,check=True)


def main():
    return execute(parser().parse_args())


if __name__=='__main__':raise SystemExit(main())
