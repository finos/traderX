"""Real processor HTTP -> PostgreSQL candidate campaign on loopback only."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import urllib.request
import urllib.error
import uuid
import jwt
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.hazmat.primitives import serialization
import bootstrap_database
import portability
from verify_bootstrap import database,require,fingerprint
from verify_execution_reservations import MIGRATION,SETTLEMENT
from resource_operation import operation


def campaign(runtime):
    if not __debug__:raise RuntimeError('HTTP campaign requires Python assertions enabled')
    java=portability.java()
    target=runtime/'trading-security-build/trade-processor'
    report=json.loads((runtime/'evidence/trading-security-build.json').read_text())
    entry=next(x for x in report['services'] if x['service']=='trade-processor')
    jars=[p for p in (target/'build/libs').glob('*.jar') if not p.name.endswith('-plain.jar')]
    if len(jars)!=1 or hashlib.sha256(jars[0].read_bytes()).hexdigest()!=entry['jar_sha256']:raise ValueError('Unverified processor jar')
    reference=bootstrap_database.pinned_reference()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    credentials=bootstrap_database.credentials();checks=[]
    with tempfile.TemporaryDirectory(prefix='execution-http-',dir=runtime) as temp:
        private=Path(temp);key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        public=private/'public.pem';public.write_bytes(key.public_key().public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo))
        with database(runtime,image,persistent=True,loopback=True) as (sql,password,restart,pgport):
            def admin(query):return require(sql('traderx',password,query),'HTTP campaign SQL check failed')
            admin(bootstrap_database.render(reference,credentials));admin(MIGRATION.read_text());admin(SETTLEMENT.read_text())
            admin("INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms) VALUES ('http-order',22214,'IBM','Buy',10,10,100,'NEW',now(),now(),'trader','https://identity.example.test','fixture');")
            execution=str(uuid.uuid4());proc=credentials['trade-processor'];matcher=credentials['order-matcher']
            require(sql(matcher['username'],matcher['password'],f"SELECT lab_execution.reserve('{execution}','http-order',6,99);"),'Reservation failed')
            with socket.socket() as probe:probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
            url=f'http://127.0.0.1:{port}'
            env=dict(os.environ,SERVER_ADDRESS='127.0.0.1',SERVER_PORT=str(port),DATABASE_PG_HOST='127.0.0.1',DATABASE_PG_PORT=str(pgport),DATABASE_NAME='traderx',DATABASE_DBUSER=proc['username'],DATABASE_DBPASS=proc['password'],
              LAB_IDENTITY_ISSUER='https://identity.example.test',LAB_IDENTITY_AUDIENCE='traderx-execution',LAB_IDENTITY_PUBLIC_KEY_FILE=str(public),LAB_IDENTITY_KEY_NOT_AFTER=time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime(time.time()+1800)),LAB_EXECUTION_MATCHER_SUBJECT='matcher-service',SPRING_JPA_SHOW_SQL='false',LOGGING_LEVEL_ORG_HIBERNATE_SQL='OFF')
            log=runtime/'evidence/execution-http-private.log'
            child=None
            def call(path,token=None,method='POST',body=None):
                headers={} if token is None else {'Authorization':'Bearer '+token}
                if body is not None:headers['Content-Type']='application/json'
                request=urllib.request.Request(url+path,headers=headers,method=method,data=None if body is None else body.encode())
                try:
                    with urllib.request.urlopen(request,timeout=15) as response:return response.status,response.read().decode()
                except urllib.error.HTTPError as error:return error.code,error.read().decode()
            def token(subject='matcher-service',audience='traderx-execution',expires=300):
                now=int(time.time());return jwt.encode({'iss':'https://identity.example.test','sub':subject,'aud':audience,'iat':now-60,'exp':now+expires},key,algorithm='RS256')
            def start():
                nonlocal child
                with log.open('a') as output:
                    log.chmod(0o600)
                    child=subprocess.Popen([java,'-Xmx256m','-XX:MaxMetaspaceSize=192m','-jar',str(jars[0])],env=env,stdout=output,stderr=subprocess.STDOUT)
                deadline=time.monotonic()+90
                while time.monotonic()<deadline:
                    if child.poll() is not None:raise RuntimeError('Processor exited; inspect private log')
                    try:
                        if call('/actuator/health',method='GET')[0]==200:return
                    except OSError:pass
                    time.sleep(.5)
                raise RuntimeError('Processor readiness timed out')
            def stop():
                if child and child.poll() is None:
                    child.terminate()
                    try:child.wait(timeout=20)
                    except subprocess.TimeoutExpired:child.kill();child.wait(timeout=10)
            try:
                start();path='/internal/executions/'+execution
                before=fingerprint(sql,password)
                for label,bearer,expected in [('anonymous',None,401),('user audience',token(audience='traderx-api'),401),('wrong service',token(subject='trader'),403),('expired',token(expires=-1),401)]:
                    assert call(path,bearer)[0]==expected,label
                    assert fingerprint(sql,password)==before,label
                    checks.append(label+' rejected without database effects')
                assert call(path,token(),body='{"accountId":44044}')[0]==400
                assert call('/tradeservice/order',token(),body='{}')[0]==403
                assert admin("SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM';")=='-100'
                assert call('/internal/executions/'+str(uuid.uuid4()),token())[0]==409
                assert fingerprint(sql,password)==before
                checks.append('unreserved execution rejected')
                checks.append('payload override and legacy HTTP booking rejected without position effects')
                with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                    results=list(pool.map(lambda _:call(path,token()),range(2)))
                for status,body in results:assert status==200 and json.loads(body)['tradeId']==execution
                assert admin(f"SELECT count(*) FROM trades WHERE id='{execution}';")=='1'
                assert admin("SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM';")=='-94'
                assert admin("SELECT remainingquantity FROM orderbook WHERE orderid='http-order';")=='4'
                checks.append('concurrent authenticated HTTP requests settle exactly once in PostgreSQL')
                stop();env['DATABASE_PG_PORT']=str(restart());start()
                assert call(path,token())[0]==200
                assert admin("SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM';")=='-94'
                checks.append('processor and database restart preserve duplicate protection')
            finally:stop()
    return {'status':'passed','scope':'Processor HTTP and PostgreSQL integration candidate, not deployed', 'jar_sha256':entry['jar_sha256'],'migration_sha256':hashlib.sha256(MIGRATION.read_bytes()).hexdigest(),'settlement_sha256':hashlib.sha256(SETTLEMENT.read_bytes()).hexdigest(),'image':image,'checks':checks,
      'limitations':['Synthetic signed tokens, not live Keycloak; HTTP loopback, not deployment TLS','Matcher dispatch, live policy revocation and broker/event delivery remain pending','Legacy NATS subscription disabled in candidate; no normal trading cutover']}

def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',required=True,type=Path);parser.add_argument('--output',required=True,type=Path);args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=campaign(args.runtime_dir)
    with args.output.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print('Authenticated HTTP to PostgreSQL execution checks passed; runtime unchanged.')
if __name__=='__main__':main()
