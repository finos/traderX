"""Strict container-only entrypoints for the first three protected Python roles."""
import argparse
import os
from pathlib import Path
import sys

CONFIG='/run/private/config/config.json'
PRIVATE=Path('/run/private/config')
BACKENDS={'account-service','position-service','order-matcher','reference-data','price-publisher'}


def validate(role,config):
    if role=='browser-session':
        if config['listen_host']!='0.0.0.0' or config['listen_port']!=18447 or config['static_root']!='/app/static':
            raise ValueError('Packaged browser listener/static contract required')
        if set(config['backends'])!=BACKENDS:raise ValueError('Complete approved API origin inventory required')
        for key,filename in (('certificate','tls.crt'),('key','tls.key'),('ca_file','ca.pem')):
            if config[key]!=str(PRIVATE/filename):raise ValueError('Materialized browser TLS files required')
        if 'broker' in config and config['broker']['ca_file']!=str(PRIVATE/'ca.pem'):
            raise ValueError('Materialized broker trust required')
    else:
        expected={'event-publisher':'publisher','event-consumer':'reference-consumer'}[role]
        if config['mode']!=expected or config['database_transport']!='verify-full':
            raise ValueError('Exact delivery role and verified database TLS required')
        for key,filename in (('broker_ca','broker-ca.pem'),('database_ca','database-ca.pem')):
            if config[key]!=str(PRIVATE/filename):raise ValueError('Materialized delivery trust required')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--role',required=True,choices=('browser-session','event-publisher','event-consumer'))
    parser.add_argument('--config',required=True);args=parser.parse_args()
    try:
        if os.geteuid()!=10001 or os.getegid()!=10001 or args.config!=CONFIG:
            raise ValueError('Fixed non-root runtime identity and config required')
        if args.role=='browser-session':
            import browser_runtime as runtime
        else:
            import delivery_worker as runtime
        config=runtime.load_config(CONFIG)
        validate(args.role,config)
    except Exception:
        print('Packaged runtime configuration refused; private details withheld.',file=sys.stderr)
        return 2
    sys.argv=[sys.argv[0],'--config',CONFIG]
    return runtime.main()


if __name__=='__main__':raise SystemExit(main())
