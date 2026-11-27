"""Disposable real PostgreSQL execution-reservation campaign; no settlement claim."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import uuid
import bootstrap_database
from resource_operation import operation
from verify_bootstrap import database, require

ROOT=Path(__file__).resolve().parents[2]
SETTLEMENT=ROOT/'specs/019-traderx-security-lab/system/sql/execution-settlement.sql'
MIGRATION=ROOT/'specs/019-traderx-security-lab/system/sql/execution-reservations.sql'

def campaign(runtime):
    reference=bootstrap_database.pinned_reference()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    identities=bootstrap_database.credentials()
    checks=[]
    with database(runtime,image,persistent=True) as (execute,password,restart):
        def admin(sql):return require(execute('traderx',password,sql),'Bootstrap operation failed')
        def matcher(sql):return execute('lab_order_matcher',identities['order-matcher']['password'],sql)
        def reject(result,label):
            if result.returncode==0:raise AssertionError(label+' unexpectedly accepted')
            checks.append(label)
        admin(bootstrap_database.render(reference,identities))
        admin(MIGRATION.read_text())
        admin(SETTLEMENT.read_text())
        # Synthetic accepted orders only. Existing C3 seed orders intentionally lack authority.
        admin("""INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms)
          VALUES ('lab-reserve',22214,'IBM','Buy',10,10,100,'NEW',now(),now(),'trader','https://identity.example.test','fixture'),
                 ('lab-race',22214,'IBM','Buy',10,10,100,'NEW',now(),now(),'trader','https://identity.example.test','fixture');""")
        admin("INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat) VALUES ('lab-legacy',22214,'IBM','Buy',10,10,100,'NEW',now(),now());")
        def request(identifier,order='lab-reserve',qty=6,price='99'):
            return f"SELECT lab_execution.reserve('{identifier}','{order}',{qty},{price});"
        identifier=str(uuid.uuid4())
        assert require(matcher(request(identifier)),'Reservation failed')==identifier
        assert require(matcher(request(identifier)),'Retry failed')==identifier
        assert admin('SELECT count(*) FROM lab_execution.reservations;')=='1'
        checks.append('identical retry has one persistent reservation')
        reject(matcher(request(identifier,qty=5)),'changed payload conflicts')
        reject(matcher(request(identifier,order='lab-race')),'cross-order substitution conflicts')
        reject(matcher(request(str(uuid.uuid4()),qty=5)),'aggregate quantity overrun denied')
        reject(matcher(request(str(uuid.uuid4()),qty=1,price='101')),'limit-price violation denied')
        reject(matcher(request(str(uuid.uuid4()),qty=1,price="'NaN'::numeric")),'non-finite price denied')
        reject(matcher(request(str(uuid.uuid4()),order='lab-legacy',qty=1)),'legacy order without authority denied')
        reject(matcher('UPDATE lab_execution.reservations SET quantity=1;'),'runtime ledger mutation denied')
        reject(matcher('DELETE FROM lab_execution.reservations;'),'runtime ledger deletion denied')
        reject(matcher('ALTER TABLE orderbook ADD COLUMN unauthorized int;'),'runtime DDL denied')
        reject(execute('lab_account',identities['account-service']['password'],request(str(uuid.uuid4()))),'unrelated identity denied')
        with ThreadPoolExecutor(max_workers=2) as pool:
            results=list(pool.map(matcher,[request(str(uuid.uuid4()),'lab-race',6),request(str(uuid.uuid4()),'lab-race',6)]))
        assert sum(r.returncode==0 for r in results)==1
        assert admin("SELECT sum(quantity) FROM lab_execution.reservations WHERE order_id='lab-race';")=='6'
        checks.append('concurrent over-reservation serialized')
        restart()
        assert require(matcher(request(identifier)),'Restart retry failed')==identifier
        assert admin("SELECT count(*) FROM lab_execution.reservations WHERE execution_id='"+identifier+"';")=='1'
        checks.append('restart preserves reservation and retry identity')
        admin("UPDATE orderbook SET status='CANCELED',remainingquantity=0 WHERE orderid='lab-reserve';")
        reject(matcher(request(str(uuid.uuid4()),qty=1)),'new reservation after cancellation denied')
        # Known ID remains a historical lookup, not permission to execute again.
        assert require(matcher(request(identifier)),'Historical lookup failed')==identifier
        checks.append('cancellation preserves historical retry record')
        reject(execute('traderx',password,MIGRATION.read_text()),'repeat migration refused atomically')
        assert admin('SELECT count(*) FROM lab_execution.reservations;')=='2'
        def processor(sql):return execute('lab_trade_processor',identities['trade-processor']['password'],sql)
        race=admin("SELECT execution_id FROM lab_execution.reservations WHERE order_id='lab-race';")
        settle="SELECT lab_execution.settle('"+race+"');"
        reject(matcher(settle),'matcher cannot settle its own reservation')
        reject(processor("SELECT lab_execution.settle('"+identifier+"');"),'canceled reservation cannot settle')
        reject(processor("SELECT lab_execution.settle('"+str(uuid.uuid4())+"');"),'unreserved execution cannot settle')
        with ThreadPoolExecutor(max_workers=2) as pool:
            settled=list(pool.map(processor,[settle,settle]))
        for result in settled:assert require(result,'Concurrent settlement failed')==race
        assert admin("SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM';")=='-94'
        assert admin("SELECT count(*) FROM trades WHERE id='"+race+"';")=='1'
        assert admin("SELECT remainingquantity FROM orderbook WHERE orderid='lab-race';")=='4'
        checks.append('concurrent duplicate settlement changes trade position and order exactly once')
        restart()
        assert require(processor(settle),'Settled retry after restart failed')==race
        assert admin("SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM';")=='-94'
        checks.append('settled retry after restart has no duplicate effect')
        final=str(uuid.uuid4())
        require(matcher(request(final,'lab-race',4)),'Remaining quantity reservation failed')
        require(processor("BEGIN; SELECT lab_execution.settle('"+final+"'); ROLLBACK;"),'Rollback probe failed')
        assert admin("SELECT count(*) FROM trades WHERE id='"+final+"';")=='0'
        assert admin("SELECT count(*) FROM lab_execution.receipts WHERE execution_id='"+final+"';")=='0'
        assert admin("SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM';")=='-94'
        assert admin("SELECT remainingquantity FROM orderbook WHERE orderid='lab-race';")=='4'
        checks.append('rollback removes receipt trade position and order effects together')
        require(processor("SELECT lab_execution.settle('"+final+"');"),'Final fill failed')
        assert admin("SELECT status FROM orderbook WHERE orderid='lab-race';")=='FILLED'
        assert admin("SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM';")=='-90'
        checks.append('remaining authorized quantity settles to FILLED')
    return {'status':'passed','scope':'PostgreSQL reservation and atomic settlement candidate; no authenticated HTTP or broker integration',
      'image':image,'migration_sha256':hashlib.sha256(MIGRATION.read_bytes()).hexdigest(),'settlement_sha256':hashlib.sha256(SETTLEMENT.read_bytes()).hexdigest(),'checks':checks,
      'limits':{'memory_mib':256,'cpu':1,'host_ports':0},
      'limitations':['Not integrated with matcher, trade service, NATS or processor','Stored authority is trusted application metadata, not independently verified by this ledger','SQL receipts deduplicate candidate settlement only; deployed Java processor remains unchanged','No broker event outbox or HTTP authentication integration; no end-to-end delivery guarantee']}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,required=True);parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=campaign(args.runtime_dir)
    with args.output.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print('PostgreSQL reservation and atomic settlement checks passed; application integration remains pending.')

if __name__=='__main__':main()
