"""Real PostgreSQL + authenticated TLS JetStream delivery; isolated reference projection."""
import argparse
import asyncio
import hashlib
import importlib.metadata
import json
from pathlib import Path
import secrets
import ssl
import subprocess
import tempfile
import uuid

import bootstrap_database
from event_delivery import Publisher, Store, STREAM, connect_broker, consume_message
from jetstream_fixture import broker, IMAGE as NATS_IMAGE, SUBJECTS
from resource_operation import operation
from verify_bootstrap import database, require, fingerprint
from verify_execution_reservations import MIGRATION, SETTLEMENT
from verify_execution_events import EVENTS

ROOT=Path(__file__).resolve().parents[2]
CONSUMER=ROOT/'specs/019-traderx-security-lab/system/sql/execution-consumer.sql'


async def campaign(runtime):
    import psycopg
    from nats.errors import Error as NatsError, TimeoutError as NatsTimeout
    from nats.js.api import StreamConfig, ConsumerConfig, StorageType, AckPolicy, DiscardPolicy
    reference=bootstrap_database.pinned_reference()
    image=next(d for d in reference['items'] if d['kind']=='Deployment' and d['metadata']['name']=='database')['spec']['template']['spec']['containers'][0]['image']
    identities=bootstrap_database.credentials();checks=[]
    def check(value,label):
        if not value:raise AssertionError(label)
        checks.append(label)
    with database(runtime,image,persistent=True,loopback=True) as (sql,password,restart_db,pgport):
        def admin(query):return require(sql('traderx',password,query),'Delivery bootstrap/check failed')
        def business():return fingerprint(sql,password)
        admin(bootstrap_database.render(reference,identities))
        for path in (MIGRATION,SETTLEMENT,EVENTS,CONSUMER):admin(path.read_text())
        db_passwords={role:secrets.token_hex(24) for role in ('event_publisher','event_consumer_a','event_consumer_b')}
        for role,secret in db_passwords.items():
            group='lab_event_publisher' if role=='event_publisher' else 'lab_event_consumer'
            admin(f"CREATE ROLE {role} LOGIN PASSWORD '{secret}' IN ROLE {group}; GRANT CONNECT ON DATABASE traderx TO {role};")
        admin("INSERT INTO lab_execution.consumer_accounts VALUES ('event_consumer_a',22214),('event_consumer_b',62654);")
        for order,account in [('delivery-a',22214),('delivery-b',62654)]:
            admin(f"INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms) VALUES ('{order}',{account},'IBM','Buy',10,10,999999999999999.999,'NEW',now(),now(),'trader','https://identity.example.test','fixture');")
        executions=[]
        for order,qty,price in [('delivery-a',6,99),('delivery-a',4,98),('delivery-b',10,'900719925474099.123')]:
            eid=str(uuid.uuid4());executions.append(eid)
            for service,query in [('order-matcher',f"SELECT lab_execution.reserve('{eid}','{order}',{qty},{price});"),('trade-processor',f"SELECT lab_execution.settle('{eid}');")]:
                identity=identities[service];require(sql(identity['username'],identity['password'],query),'Settlement failed')
        before=business()
        rows=json.loads(admin('SELECT json_agg(e ORDER BY event_sequence) FROM lab_execution.events e;'))
        def envelope(row):return {'eventId':row['event_id'],'eventSequence':row['event_sequence'],'executionId':row['execution_id'],'eventKind':row['event_kind'],'payload':row['payload']}
        def projection():return admin("SELECT json_build_object('inbox',(SELECT json_agg(i ORDER BY login_role,event_id) FROM lab_execution.consumer_inbox i),'trades',(SELECT json_agg(t ORDER BY login_role,event_id) FROM lab_execution.trade_projection t),'positions',(SELECT json_agg(p ORDER BY login_role,account_id,security) FROM lab_execution.position_projection p));")
        connections=[];clients=[];errors={}
        async def store(role):
            connection=await psycopg.AsyncConnection.connect(host='127.0.0.1',port=pgport,dbname='traderx',user=role,
                password=db_passwords[role],autocommit=True,connect_timeout=3,options='-c statement_timeout=3000 -c lock_timeout=3000')
            connections.append(connection);return Store(connection)
        with broker(runtime) as fixture:
            endpoint=fixture['endpoint']
            async def client(user):
                errors[user]=[]
                connection=await connect_broker(endpoint,user,fixture['passwords'][user],fixture['ca'],errors[user]);clients.append(connection);return connection
            async def rejected(awaitable,label,state=None):
                try:await awaitable
                except (psycopg.Error,ValueError,TimeoutError,OSError) as error:
                    if state and getattr(error,'sqlstate',None)!=state:raise AssertionError(label+' wrong SQL failure') from None
                    checks.append(label)
                else:raise AssertionError(label)
            try:
                bootstrap=await client('bootstrap');js=bootstrap.jetstream()
                await js.add_stream(config=StreamConfig(name=STREAM,subjects=SUBJECTS,storage=StorageType.FILE,
                    max_bytes=8388608,max_msgs=10000,max_age=86400,discard=DiscardPolicy.NEW,
                    duplicate_window=1.0,num_replicas=1,max_msg_size=8192))
                for durable,account in [('ACCOUNT_A',22214),('ACCOUNT_B',62654)]:
                    await js.add_consumer(STREAM,config=ConsumerConfig(durable_name=durable,
                      filter_subjects=[f'/accounts/{account}/trades',f'/accounts/{account}/positions'],
                      ack_policy=AckPolicy.EXPLICIT,ack_wait=1.0,max_ack_pending=32,max_deliver=-1))
                check((await js.stream_info(STREAM)).config.storage==StorageType.FILE,'file-backed stream provisioned by separate bootstrap identity')
                # Wrong credentials must fail at the actual server, not a mocked adapter.
                try:await connect_broker(endpoint,'publisher','wrong',fixture['ca'],[])
                except NatsError as error:
                    check('Authorization Violation' in str(error),'wrong broker credential refused')
                else:raise AssertionError('Wrong credential accepted')
                with tempfile.TemporaryDirectory(prefix='untrusted-',dir=runtime) as temp:
                    bad_ca=Path(temp)/'cert.pem'
                    subprocess.run(['openssl','req','-x509','-newkey','rsa:2048','-nodes','-keyout',str(Path(temp)/'key.pem'),'-out',str(bad_ca),'-days','1','-subj','/CN=untrusted'],capture_output=True,check=True,timeout=30)
                    try:await connect_broker(endpoint,'publisher',fixture['passwords']['publisher'],bad_ca,[])
                    except ssl.SSLCertVerificationError:checks.append('untrusted broker certificate refused')
                    else:raise AssertionError('Untrusted certificate accepted')
                pub=await client('publisher');ps=await store('event_publisher');worker=uuid.uuid4()
                claimed=(await ps.claim(worker,1,1))[0]
                class LoseSqlAck:
                    async def acknowledge(self,*args):raise OSError('simulated publisher crash before SQL acknowledgment')
                publisher=Publisher(LoseSqlAck(),pub.jetstream(),worker)
                await rejected(publisher.deliver(claimed),'broker acceptance followed by injected publisher acknowledgment loss')
                check(admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;')=='0','publisher loss leaves outbox pending')
                check((await js.stream_info(STREAM)).state.messages==1,'real broker persisted event before publisher acknowledgment loss')
                await pub.close();await ps.connection.close()
                await asyncio.sleep(1.3)  # Deliberately beyond this fixture's lease and duplicate window.
                pub=await client('publisher');ps=await store('event_publisher');publisher=Publisher(ps,pub.jetstream())
                check(await publisher.run_once()==6,'new publisher identity reclaims pending events after lease expiry')
                check((await js.stream_info(STREAM)).state.messages==7,'replay beyond broker duplicate window creates a real duplicate')
                check(admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;')=='6','SQL acknowledges all events only after broker acceptance')
                # Ordinary services cannot use management APIs or publish other-account/control traffic.
                count=(await js.stream_info(STREAM)).state.messages
                for user,subject in [('publisher','$JS.API.STREAM.DELETE.SECURITY_EVENTS'),('consumer-a','/accounts/62654/trades')]:
                    nc=pub if user=='publisher' else await client(user)
                    prior=len(errors[user]);await nc.publish(subject,b'{}');await nc.flush(timeout=3)
                    deadline=asyncio.get_running_loop().time()+2
                    while len(errors[user])==prior and asyncio.get_running_loop().time()<deadline:await asyncio.sleep(.02)
                    check(len(errors[user])>prior,user+' forbidden publish rejected by broker')
                check((await js.stream_info(STREAM)).state.messages==count,'forbidden broker operations leave stream intact')
                foreign_sub=await nc.jetstream().pull_subscribe_bind(consumer='ACCOUNT_B',stream=STREAM,pending_msgs_limit=4,pending_bytes_limit=8192)
                try:await foreign_sub.fetch(1,timeout=.5)
                except NatsTimeout:checks.append('consumer cannot pull another account durable subscription')
                else:raise AssertionError('Cross-account durable pull accepted')
                await foreign_sub.unsubscribe()
                check((await js.consumer_info(STREAM,'ACCOUNT_B')).delivered.consumer_seq==0,'denied cross-account pull delivers no message')
                # Broker + PostgreSQL restart before consumers; bindings and immutable events survive.
                for nc in clients:await nc.close()
                for connection in connections:await connection.close()
                endpoint=fixture['restart']();pgport=restart_db()
                bootstrap=await client('bootstrap');js=bootstrap.jetstream()
                check((await js.stream_info(STREAM)).state.messages==7,'broker restart retains accepted events on disk')
                check(admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;')=='6','database restart retains outbox acknowledgments')
                ca=await client('consumer-a');cb=await client('consumer-b')
                sa=await store('event_consumer_a');sb=await store('event_consumer_b')
                suba=await ca.jetstream().pull_subscribe_bind(consumer='ACCOUNT_A',stream=STREAM,pending_msgs_limit=32,pending_bytes_limit=65536)
                subb=await cb.jetstream().pull_subscribe_bind(consumer='ACCOUNT_B',stream=STREAM,pending_msgs_limit=32,pending_bytes_limit=65536)
                first=(await suba.fetch(1,timeout=3))[0]
                # Real DB commit, but no broker ack: represent process exit in that exact window.
                event=json.loads(first.data)
                check(await sa.consume(first.subject,event)=='applied','consumer commits first effect before lost broker acknowledgment')
                committed=projection();await ca.close()
                for connection in connections:await connection.close()
                pgport=restart_db();sb=await store('event_consumer_b')
                check(projection()==committed,'database restart preserves committed consumer inbox and effect')
                await asyncio.sleep(1.2)
                ca=await client('consumer-a');sa=await store('event_consumer_a')
                suba=await ca.jetstream().pull_subscribe_bind(consumer='ACCOUNT_A',stream=STREAM,pending_msgs_limit=32,pending_bytes_limit=65536)
                replay=(await suba.fetch(1,timeout=3))[0]
                check(json.loads(replay.data)['eventId']==event['eventId'] and replay.metadata.num_delivered>1,'new consumer receives actual unacknowledged redelivery')
                check(await consume_message(sa,replay)=='duplicate' and projection()==committed,'redelivery commits no second projection effect')
                results=[]
                for _ in range(4):results.append(await consume_message(sa,(await suba.fetch(1,timeout=3))[0]))
                for _ in range(2):results.append(await consume_message(sb,(await subb.fetch(1,timeout=3))[0]))
                check(results.count('duplicate')==1,'broker-window duplicate suppressed by persistent consumer inbox')
                check(admin('SELECT count(*) FROM lab_execution.consumer_inbox;')=='6','one inbox entry per event and entitled consumer')
                check(admin('SELECT count(*) FROM lab_execution.trade_projection;')=='3','three notifications projected without rebooking trades')
                check(json.loads(admin("SELECT payload::text FROM lab_execution.position_projection WHERE login_role='event_consumer_a';"))['quantity']==-90,'latest authorized position projection has settled quantity')
                check(admin("SELECT (payload->>'price')::numeric=900719925474099.123 FROM lab_execution.trade_projection WHERE login_role='event_consumer_b';")=='t','broker and consumer preserve full PostgreSQL financial decimal precision')
                check((await js.consumer_info(STREAM,'ACCOUNT_A')).num_ack_pending==0,'consumer acknowledgments reach broker after committed effects')
                stable=projection();foreign=rows[-1]
                await rejected(sa.consume(foreign['topic'],envelope(foreign)),'database login cannot consume another account even with valid event','22023')
                forged=envelope(rows[0]);forged['payload']=dict(forged['payload'],quantity=999)
                await rejected(sa.consume(rows[0]['topic'],forged),'forged event payload rejected against canonical outbox','22023')
                await rejected(sa.consume('/accounts/62654/trades',envelope(rows[0])),'topic substitution rejected','22023')
                check(projection()==stable,'denied consumer operations leave inbox and projection unchanged')
                # A fresh scoped projection receives snapshots in reverse order.
                admin('DELETE FROM lab_execution.consumer_inbox; DELETE FROM lab_execution.trade_projection; DELETE FROM lab_execution.position_projection;')
                newer=rows[3];older=rows[1]
                check(await sa.consume(newer['topic'],envelope(newer))=='applied','newer position snapshot applied first')
                check(await sa.consume(older['topic'],envelope(older))=='stale','older snapshot recorded but cannot overwrite newer position')
                check(json.loads(admin("SELECT payload::text FROM lab_execution.position_projection WHERE login_role='event_consumer_a';"))['quantity']==-90,'out-of-order position effect preserves newest sequence')
                # Force a failure after inbox insertion: transaction must undo inbox and effect together.
                admin("CREATE FUNCTION lab_execution.fail_projection() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic failure'; END $$; CREATE TRIGGER fail_projection BEFORE INSERT ON lab_execution.trade_projection FOR EACH ROW EXECUTE FUNCTION lab_execution.fail_projection();")
                stable=projection()
                await rejected(sa.consume(rows[0]['topic'],envelope(rows[0])),'projection failure rejects consumer transaction','P0001')
                check(projection()==stable,'projection failure rolls back inbox insertion')
                admin('DROP TRIGGER fail_projection ON lab_execution.trade_projection; DROP FUNCTION lab_execution.fail_projection();')
                # Concurrent redelivery across distinct DB sessions still applies only once.
                sa2=await store('event_consumer_a')
                result=await asyncio.gather(sa.consume(rows[0]['topic'],envelope(rows[0])),sa2.consume(rows[0]['topic'],envelope(rows[0])))
                check(sorted(result)==['applied','duplicate'],'concurrent consumer retry applies effect once')
                for query in ['SELECT * FROM lab_execution.events','DELETE FROM lab_execution.consumer_inbox','UPDATE public.positions SET quantity=999','DELETE FROM lab_execution.consumer_accounts']:
                    await rejected(sa.connection.execute(query),'consumer SQL denied: '+query.split()[0]+' '+query.split()[-1],'42501')
                check(business()==before,'all delivery replay and rejection leaves trading business tables unchanged')
                final_info=await js.stream_info(STREAM)
                return {'status':'passed','scope':'TLS JetStream + PostgreSQL reference projection; not deployed UI delivery',
                  'checks':checks,'broker_version':str(bootstrap.connected_server_version),'broker_messages':final_info.state.messages,
                  'images':{'nats':NATS_IMAGE,'postgresql':image},
                  'client_versions':{p:importlib.metadata.version(p) for p in ('nats-py','psycopg','psycopg-binary','simplejson')},
                  'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (MIGRATION,SETTLEMENT,EVENTS,CONSUMER,Path(__file__).resolve(),ROOT/'scripts/security-lab/event_delivery.py',ROOT/'scripts/security-lab/jetstream_fixture.py',ROOT/'scripts/security-lab/requirements-delivery.txt')},
                  'limits':{'postgresql_memory_mib':256,'broker_memory_mib':128,'broker_store_bytes':16777216,'loopback_ports':2},
                  'limitations':['Single-node graceful restart, not host power loss or replicated high availability',
                    'Acknowledgment-loss fault injection after actual broker acceptance/consumer commit, not a demonstrated exploit',
                    'Reference projection shares the authoritative outbox database; not an independent distributed verification boundary',
                    'Existing Java/Node/browser consumers and deployment credential/TLS provisioning are not cut over',
                    'Finite retention and poison-message handling need an operator recovery policy before deployment']}
            finally:
                for nc in clients:await nc.close()
                for connection in connections:await connection.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--runtime-dir',type=Path,required=True);parser.add_argument('--output',type=Path,required=True);args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=asyncio.run(campaign(args.runtime_dir))
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print(f"TLS broker and scoped consumer delivery: {len(result['checks'])} checks passed; deployed cutover remains pending.")

if __name__=='__main__':main()
