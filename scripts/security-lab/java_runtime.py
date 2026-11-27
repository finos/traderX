"""Fixed private Spring startup adapters for explicitly reviewed Java roles."""
import argparse
from datetime import datetime, timezone, timedelta
import ipaddress
import json
import os
from pathlib import Path
import re
import secrets
import ssl
import subprocess
import tempfile
import stat
import sys
from urllib.parse import urlsplit

PRIVATE=Path('/run/private/config')
CONFIG=PRIVATE/'config.json'
PROPERTIES=Path('/run/private/java/application.properties')
KEYS=['config.json','database-ca.pem','entitlements.properties','public.pem','tls.p12']
MATCHER_KEYS=sorted(KEYS+['broker-ca.pem','broker-secret','client-secret','identity-ca.pem','processor-ca.pem'])
OUTBOUND=PROPERTIES.parent/'outbound-trust.p12'
KEYTOOL='/opt/java/openjdk/bin/keytool'
ROLES={
    'position-service':{'port':18090,'audience':'traderx-api','keys':KEYS},
    'account-service':{'port':18088,'audience':'traderx-api','keys':KEYS},
    'trade-processor':{'port':18091,'audience':'traderx-execution',
        'keys':['config.json','database-ca.pem','public.pem','tls.p12']},
    'order-matcher':{'port':18110,'audience':'traderx-api','keys':MATCHER_KEYS}}
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
    exact(config,('version','role','database','identity','tls','execution','broker')
        if role=='order-matcher' else ('version','role','database','identity','tls'))
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
    if role=='order-matcher':
        execution=config['execution'];exact(execution,('endpoint','token_endpoint','client_id'))
        endpoint=scalar(execution['endpoint'],r'https://[a-z0-9.-]+:18091/internal/executions/')
        peer=urlsplit(endpoint)
        if not peer.hostname or any(not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?',part) for part in peer.hostname.split('.')):
            raise ValueError('Explicit processor HTTPS host required')
        if execution['token_endpoint']!=issuer+'/protocol/openid-connect/token':
            raise ValueError('Service token endpoint must belong to the trusted issuer')
        scalar(execution['client_id'],r'[A-Za-z0-9_-]{1,128}')
        broker=config['broker'];exact(broker,('host','port','username'))
        scalar(broker['host'],r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?')
        if type(broker['port']) is not int or broker['port']!=4222:raise ValueError('Fixed TLS broker port required')
        scalar(broker['username'],r'[A-Za-z0-9_-]{1,64}')
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
    if role=='order-matcher':
        for name in ('broker-secret','client-secret'):
            scalar(private_file(PRIVATE/name).decode('ascii'),r'[A-Za-z0-9_-]{16,256}')
        for name in ('broker-ca.pem','identity-ca.pem','processor-ca.pem'):
            public_certificate(private_file(PRIVATE/name))
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
    if role=='order-matcher':
        values.update({
            'spring.jpa.database-platform':'org.hibernate.dialect.PostgreSQLDialect',
            'spring.jpa.hibernate.naming.physical-strategy':'org.hibernate.boot.model.naming.PhysicalNamingStrategyStandardImpl',
            'spring.jpa.open-in-view':'false','order.matcher.seed-enabled':'false',
            'order.matcher.publisher':'nats','order.matcher.pricing-subscriber.enabled':'true',
            'order.matcher.tick-ms':'1000','order.matcher.fill-full-threshold':'1000',
            # These inherited metadata fields are never used for network access
            # by the protected execution path. Never retain anonymous defaults.
            'order.matcher.price-service-url':'disabled','order.matcher.trade-service-url':'disabled',
            'nats.address':'tls://'+config['broker']['host']+':4222',
            'lab.broker.username':config['broker']['username'],'lab.broker.secret-file':str(PRIVATE/'broker-secret'),
            'lab.execution.enabled':'true','lab.execution.endpoint':config['execution']['endpoint'],
            'lab.execution.token-endpoint':config['execution']['token_endpoint'],
            'lab.execution.client-id':config['execution']['client_id'],'lab.execution.secret-file':str(PRIVATE/'client-secret')})
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


def public_certificate(raw):
    # One public X.509 PEM per reviewed peer: no key, bundle or extra content.
    if not re.fullmatch(rb'-----BEGIN CERTIFICATE-----\r?\n[A-Za-z0-9+/=\r\n]+\r?\n-----END CERTIFICATE-----\r?\n?',raw):
        raise ValueError('Single public certificate required')
    ssl.PEM_cert_to_DER_cert(raw.decode('ascii'))


def outbound_truststore():
    # write_properties has already reserved and checked this owned 0700 parent.
    parent=PROPERTIES.parent
    info=parent.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid!=os.geteuid() or stat.S_IMODE(info.st_mode)!=0o700:
        raise ValueError('Private trust output directory required')
    if OUTBOUND.exists() or OUTBOUND.is_symlink():raise ValueError('Fresh trust store required')
    with tempfile.TemporaryDirectory(prefix='.outbound-',dir=parent) as temporary:
        store=Path(temporary)/'trust.p12'
        for alias in ('identity','processor','broker'):
            certificate=PRIVATE/(alias+'-ca.pem');public_certificate(private_file(certificate))
            # importcert can create only trustedCertEntry entries; never import
            # a private key or use the server key-store password here.
            subprocess.run([KEYTOOL,'-importcert','-noprompt','-J-Xmx64m','-alias',alias,'-file',str(certificate),
                '-keystore',str(store),'-storetype','PKCS12','-storepass','changeit'],
                stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,check=True,timeout=15,
                env={'PATH':'/usr/bin:/bin','LANG':'C.UTF-8'},umask=0o077)
        private_file(store)
        os.link(store,OUTBOUND,follow_symlinks=False)


def check_environment(environment):
    forbidden=('SPRING_','SERVER_','DATABASE_','LAB_','MANAGEMENT_','LOGGING_',
               'POSITION_SERVICE_','ACCOUNT_SERVICE_','TRADE_PROCESSOR_','ORDER_MATCHER_','NATS_')
    if any(key.upper().startswith(forbidden) or key in ('JAVA_TOOL_OPTIONS','JDK_JAVA_OPTIONS','_JAVA_OPTIONS','CLASSPATH') for key in environment):
        raise ValueError('Runtime environment overrides refused')


def argv(role='position-service'):
    role_contract(role)
    command=[JAVA,'-Xmx256m','-XX:MaxMetaspaceSize=192m','-XX:+ExitOnOutOfMemoryError']
    if role=='order-matcher':
        # Public-cert-only trust store. changeit is not a private credential.
        command+=['-Djavax.net.ssl.trustStore='+str(OUTBOUND),
                  '-Djavax.net.ssl.trustStoreType=PKCS12','-Djavax.net.ssl.trustStorePassword=changeit']
    return command+['-jar',JAR,'--spring.config.location=file:'+str(PROPERTIES)]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--role',required=True,choices=ROLES);parser.add_argument('--config',required=True)
    args=parser.parse_args()
    try:
        if os.geteuid()!=10001 or os.getegid()!=10001 or args.config!=str(CONFIG):raise ValueError('Fixed runtime identity and config required')
        check_environment(os.environ);write_properties(properties(load_config(args.role),role=args.role))
        if args.role=='order-matcher':outbound_truststore()
    except Exception:
        print('Protected Java configuration refused; private details withheld.',file=sys.stderr);return 2
    os.execve(JAVA,argv(args.role),{'PATH':'/usr/bin:/bin','LANG':'C.UTF-8','TZ':'UTC'})


if __name__=='__main__':raise SystemExit(main())
