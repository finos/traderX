"""Fixed private Spring startup adapters for explicitly reviewed Java roles."""
import argparse
from datetime import datetime, timezone, timedelta
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import stat
import sys
from urllib.parse import urlsplit

PRIVATE=Path('/run/private/config')
CONFIG=PRIVATE/'config.json'
PROPERTIES=Path('/run/private/java/application.properties')
KEYS=['config.json','database-ca.pem','entitlements.properties','public.pem','tls.p12']
ROLES={
    'position-service':{'port':18090,'audience':'traderx-api','keys':KEYS},
    'account-service':{'port':18088,'audience':'traderx-api','keys':KEYS},
    'trade-processor':{'port':18091,'audience':'traderx-execution',
        'keys':['config.json','database-ca.pem','public.pem','tls.p12']}}
JAVA='/opt/java/openjdk/bin/java'
JAR='/app/application.jar'
LIMIT=1024*1024


def exact(value,keys):
    if not isinstance(value,dict) or set(value)!=set(keys):raise ValueError('Exact configuration schema required')


def scalar(value,pattern):
    if not isinstance(value,str) or not re.fullmatch(pattern,value,re.ASCII):raise ValueError('Invalid configuration scalar')
    return value


def role_contract(role):
    if not isinstance(role,str) or role not in ROLES:raise ValueError('Reviewed Java role required')
    return ROLES[role]


def validate(config,now=None,role='position-service'):
    contract=role_contract(role)
    exact(config,('version','role','database','identity','tls'))
    if type(config['version']) is not int or config['version']!=1 or config['role']!=role:
        raise ValueError('Protected Java role configuration required')
    database=config['database'];exact(database,('host','port','name','username','password'))
    host=scalar(database['host'],r'[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?')
    try:ipaddress.IPv4Address(host)
    except ValueError:
        if any(not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?',part) for part in host.split('.')):
            raise ValueError('Database DNS name required')
    if type(database['port']) is not int or database['port']!=5432 or database['name']!='traderx':
        raise ValueError('Fixed database endpoint contract required')
    scalar(database['username'],r'[a-z][a-z0-9_]{0,62}')
    if database['username'] in ('postgres','traderx'):raise ValueError('Scoped application identity required')
    scalar(database['password'],r'[A-Za-z0-9_-]{16,256}')
    identity=config['identity'];exact(identity,('issuer','audience','key_not_after','matcher_subject')
        if role=='trade-processor' else ('issuer','audience','key_not_after'))
    if role=='trade-processor':scalar(identity['matcher_subject'],r'[A-Za-z0-9_-]{1,128}')
    issuer=scalar(identity['issuer'],r'https://[A-Za-z0-9./:_-]{1,240}')
    parsed=urlsplit(issuer)
    if not parsed.hostname or parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.port==0:
        raise ValueError('HTTPS issuer required')
    if identity['audience']!=contract['audience']:raise ValueError('Protected API audience required')
    stamp=scalar(identity['key_not_after'],r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z')
    expiry=datetime.strptime(stamp,'%Y-%m-%dT%H:%M:%SZ').replace(tzinfo=timezone.utc)
    now=now or datetime.now(timezone.utc)
    if not now<expiry<=now+timedelta(hours=8):raise ValueError('Bounded current identity trust required')
    exact(config['tls'],('password',));scalar(config['tls']['password'],r'[A-Za-z0-9_-]{16,256}')
    return config


def private_file(path):
    path=Path(path)
    if not path.is_absolute() or path.parent.resolve(strict=True)!=path.parent:raise ValueError('Direct private file required')
    fd=os.open(path,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK)
    with os.fdopen(fd,'rb') as stream:
        item=os.fstat(stream.fileno())
        if (not stat.S_ISREG(item.st_mode) or item.st_uid!=os.geteuid() or stat.S_IMODE(item.st_mode)!=0o600
                or item.st_nlink!=1 or not 0<item.st_size<=LIMIT):raise ValueError('Unsafe private input')
        raw=stream.read(LIMIT+1)
    if len(raw)>LIMIT:raise ValueError('Private input exceeds bound')
    return raw


def load_config(role='position-service'):
    keys=role_contract(role)['keys']
    def unique(items):
        result={}
        for key,value in items:
            if key in result:raise ValueError('Duplicate configuration key')
            result[key]=value
        return result
    if set(os.listdir(PRIVATE))!=set(keys):raise ValueError('Exact role private file inventory required')
    config=validate(json.loads(private_file(CONFIG),object_pairs_hook=unique),role=role)
    for name in keys:
        if name!='config.json':private_file(PRIVATE/name)
    if role=='trade-processor':return config
    # The Java security candidate validates RSA trust, PKCS12 and entitlement
    # semantics again. Refuse interpolation/newlines in its subject map here.
    subjects=set()
    for line in private_file(PRIVATE/'entitlements.properties').decode('ascii').splitlines():
        if not line or line.startswith('#'):continue
        match=re.fullmatch(r'([A-Za-z0-9_-]{1,128})=(read-only|trader|operator):([0-9,]*)',line)
        if not match or match[1] in subjects:raise ValueError('Invalid private entitlement mapping')
        subjects.add(match[1]);accounts=match[3].split(',') if match[3] else []
        if len(accounts)!=len(set(accounts)) or any(not re.fullmatch(r'[1-9][0-9]{0,9}',v) or int(v)>2147483647 for v in accounts):
            raise ValueError('Invalid private account scope')
    if not subjects:raise ValueError('Empty private entitlement mapping')
    return config


def properties(config,role='position-service'):
    validate(config,role=role);db=config['database'];identity=config['identity']
    values={
        'server.address':'0.0.0.0','server.port':str(ROLES[role]['port']),'server.forward-headers-strategy':'none',
        'server.ssl.enabled':'true','server.ssl.key-store':'file:'+str(PRIVATE/'tls.p12'),
        'server.ssl.key-store-type':'PKCS12','server.ssl.key-store-password':config['tls']['password'],
        'server.ssl.enabled-protocols':'TLSv1.3,TLSv1.2','server.max-http-request-header-size':'16KB',
        'spring.datasource.url':f'jdbc:postgresql://{db["host"]}:5432/traderx?sslmode=verify-full&sslrootcert={PRIVATE}/database-ca.pem&connectTimeout=5&socketTimeout=10',
        'spring.datasource.driver-class-name':'org.postgresql.Driver',
        'spring.datasource.username':db['username'],'spring.datasource.password':db['password'],
        'spring.datasource.hikari.maximum-pool-size':'2','spring.datasource.hikari.minimum-idle':'1',
        'spring.datasource.hikari.connection-timeout':'5000','spring.datasource.hikari.initialization-fail-timeout':'10000',
        'spring.sql.init.mode':'always','spring.sql.init.continue-on-error':'false',
        'spring.sql.init.schema-locations':'file:/opt/traderx/startup-check.sql',
        'spring.sql.init.data-locations':'file:/opt/traderx/startup-check.sql',
        'spring.jpa.hibernate.ddl-auto':'none','spring.jpa.show-sql':'false',
        'spring.main.banner-mode':'off','spring.threads.virtual.enabled':'true',
        'management.endpoints.web.exposure.include':'health','management.endpoint.health.show-details':'never',
        'management.tracing.enabled':'false','management.otlp.metrics.export.enabled':'false',
        'logging.level.org.hibernate.SQL':'OFF','logging.level.org.springframework.jdbc':'WARN',
        'lab.identity.issuer':identity['issuer'],'lab.identity.audience':identity['audience'],
        'lab.identity.public-key-file':str(PRIVATE/'public.pem'),
        'lab.identity.key-not-after':identity['key_not_after']}
    if role=='trade-processor':values['lab.execution.matcher-subject']=identity['matcher_subject']
    else:values['lab.identity.entitlements-file']=str(PRIVATE/'entitlements.properties')
    return ''.join(key+'='+values[key]+'\n' for key in sorted(values)).encode('ascii')


def write_properties(raw):
    parent=PROPERTIES.parent
    if parent.parent.resolve(strict=True)!=parent.parent or parent.is_symlink():raise ValueError('Direct private output directory required')
    # emptyDir may have a root-owned fsGroup-writable mount root. Reserve an
    # application-owned subdirectory instead of weakening file confidentiality.
    try:parent.mkdir(mode=0o700)
    except FileExistsError:pass
    fd=os.open(parent,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW)
    pending='.java-'+secrets.token_hex(16)
    try:
        info=os.fstat(fd)
        if info.st_uid!=os.geteuid() or stat.S_IMODE(info.st_mode)!=0o700:raise ValueError('Private output ownership and mode required')
        out=os.open(pending,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600,dir_fd=fd)
        try:
            with os.fdopen(out,'wb') as stream:
                os.fchmod(stream.fileno(),0o600);stream.write(raw);stream.flush();os.fsync(stream.fileno())
            os.link(pending,PROPERTIES.name,src_dir_fd=fd,dst_dir_fd=fd,follow_symlinks=False)
            os.fsync(fd)
        finally:os.unlink(pending,dir_fd=fd)
    finally:os.close(fd)


def check_environment(environment):
    forbidden=('SPRING_','SERVER_','DATABASE_','LAB_','MANAGEMENT_','LOGGING_',
               'POSITION_SERVICE_','ACCOUNT_SERVICE_','TRADE_PROCESSOR_')
    if any(key.upper().startswith(forbidden) or key in ('JAVA_TOOL_OPTIONS','JDK_JAVA_OPTIONS','_JAVA_OPTIONS','CLASSPATH') for key in environment):
        raise ValueError('Runtime environment overrides refused')


def argv():
    return [JAVA,'-Xmx256m','-XX:MaxMetaspaceSize=192m','-XX:+ExitOnOutOfMemoryError','-jar',JAR,
            '--spring.config.location=file:'+str(PROPERTIES)]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--role',required=True,choices=ROLES);parser.add_argument('--config',required=True)
    args=parser.parse_args()
    try:
        if os.geteuid()!=10001 or os.getegid()!=10001 or args.config!=str(CONFIG):raise ValueError('Fixed runtime identity and config required')
        check_environment(os.environ);write_properties(properties(load_config(args.role),role=args.role))
    except Exception:
        print('Protected Java configuration refused; private details withheld.',file=sys.stderr);return 2
    os.execve(JAVA,argv(),{'PATH':'/usr/bin:/bin','LANG':'C.UTF-8','TZ':'UTC'})


if __name__=='__main__':raise SystemExit(main())
