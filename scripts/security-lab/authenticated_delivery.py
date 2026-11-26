"""Deliver actual trading outbox records through owned worker CLI processes."""
import json
import signal

from event_delivery import STREAM, connect_broker
from jetstream_fixture import SUBJECTS
from verify_worker_process import child, end, until


def matches_notifications(page,expected_ids,account=62654):
    metadata={'eventId','executionId','eventSequence','eventKind','topic','accountId'}
    events=page.get('events',[])
    return (page.get('reset') is False and len(events)==len(expected_ids) and
        {event.get('eventId') for event in events}==expected_ids and
        all(set(event)==metadata and event['accountId']==account and
            event['topic'] in (f'/accounts/{account}/trades',f'/accounts/{account}/positions') for event in events))


def worker_configs(settings,pgport,passwords):
    base=dict(broker_endpoint=settings['endpoint'],broker_ca=str(settings['ca']),
        database_host='127.0.0.1',database_port=pgport,database_name='traderx',
        database_transport='fixture-loopback',database_ca=None,batch_size=1,
        lease_seconds=2,poll_seconds=.1,operation_timeout_seconds=10,
        retry_attempts=10,retry_base_seconds=.1,retry_cap_seconds=1,shutdown_seconds=3)
    def config(mode,broker_user,db_user):
        return dict(base,mode=mode,broker_user=broker_user,broker_password=settings['passwords'][broker_user],
            database_user=db_user,database_password=passwords[db_user])
    return (config('publisher','publisher','event_publisher'),
        dict(config('reference-consumer','consumer-b','event_consumer_b'),account_id=62654,durable='ACCOUNT_B'))


async def deliver(private,settings,pgport,passwords,admin,check):
    from nats.js.api import StreamConfig, ConsumerConfig, StorageType, AckPolicy, DiscardPolicy
    connection=await connect_broker(settings['endpoint'],'bootstrap',settings['passwords']['bootstrap'],settings['ca'])
    try:
        js=connection.jetstream()
        await js.add_stream(config=StreamConfig(name=STREAM,subjects=SUBJECTS,storage=StorageType.FILE,
            max_bytes=8388608,max_msgs=10000,max_age=86400,discard=DiscardPolicy.NEW,
            duplicate_window=1.0,num_replicas=1,max_msg_size=8192))
        await js.add_consumer(STREAM,config=ConsumerConfig(durable_name='ACCOUNT_B',
            filter_subjects=['/accounts/62654/trades','/accounts/62654/positions'],
            ack_policy=AckPolicy.EXPLICIT,ack_wait=1.0,max_ack_pending=32,max_deliver=-1))
        pub,con=worker_configs(settings,pgport,passwords)
        async def consumed():
            info=await js.consumer_info(STREAM,'ACCOUNT_B')
            return (info.num_pending==0 and info.num_ack_pending==0 and
                admin("SELECT count(*) FROM lab_execution.consumer_inbox WHERE login_role='event_consumer_b';")=='4')
        async with child(private,pub) as publisher,child(private,con) as consumer:
            await until(lambda:admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;')=='4',
                'actual settlement publisher delivery',publisher,seconds=30)
            await until(consumed,'actual settlement consumer acknowledgments',consumer,seconds=30)
            check('real CLI publisher delivers all four committed settlement events',True)
            check('scoped CLI consumer commits inbox before durable acknowledgment',True)
            check('real broker contains exactly four settlement messages',(await js.stream_info(STREAM)).state.messages==4)
            await end(publisher,signal.SIGTERM,0);await end(consumer,signal.SIGTERM,0)
        check('scoped reference consumer projects two trades and latest position',
            admin("SELECT count(*) FROM lab_execution.trade_projection WHERE login_role='event_consumer_b';")=='2' and
            admin("SELECT count(*) FROM lab_execution.position_projection WHERE login_role='event_consumer_b' AND account_id=62654 AND security='IBM';")=='1' and
            admin("SELECT count(*) FROM lab_execution.consumer_inbox WHERE (envelope->'payload'->>'accountId')::integer<>62654;")=='0')
        # Restart the actual supervised processes, not only their Python adapters.
        async with child(private,pub) as publisher,child(private,con) as consumer:
            def running(proc):
                return any(json.loads(line).get('status')=='running' for line in proc.lab_log.read_text().splitlines() if line.startswith('{'))
            await until(lambda:running(publisher),'restarted publisher healthy idle',publisher)
            await until(lambda:running(consumer),'restarted consumer healthy idle',consumer)
            check('healthy worker restart adds no duplicate settlement messages or effects',
                (await js.stream_info(STREAM)).state.messages==4 and await consumed())
            await end(publisher,signal.SIGTERM,0);await end(consumer,signal.SIGTERM,0)
    finally:await connection.close()
