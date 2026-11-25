"""Real PostgreSQL transactional outbox and fenced-delivery campaign; no broker claim."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import secrets
import time
import uuid
import bootstrap_database
from resource_operation import operation
from verify_bootstrap import database, require
from verify_execution_reservations import MIGRATION, SETTLEMENT

ROOT = Path(__file__).resolve().parents[2]
EVENTS = ROOT/'specs/019-traderx-security-lab/system/sql/execution-events.sql'


def campaign(runtime):
    reference = bootstrap_database.pinned_reference()
    image = next(d for d in reference['items'] if d['kind'] == 'Deployment' and d['metadata']['name'] == 'database')['spec']['template']['spec']['containers'][0]['image']
    identities = bootstrap_database.credentials()
    checks = []
    with database(runtime, image, persistent=True) as (execute, password, restart):
        def admin(query):
            return require(execute('traderx', password, query), 'Outbox bootstrap/check failed')
        def actor(name, query):
            identity = identities[name]
            return execute(identity['username'], identity['password'], query)
        def reject(result, label, state=None):
            if result.returncode == 0 or (state and state not in result.stderr):
                raise AssertionError(label+' did not fail as expected')
            checks.append(label)
        def check(condition, label):
            if not condition:
                raise AssertionError(label)
            checks.append(label)
        admin(bootstrap_database.render(reference, identities))
        admin(MIGRATION.read_text())
        admin(SETTLEMENT.read_text())
        admin(EVENTS.read_text())
        publisher_password = secrets.token_hex(24)
        admin("CREATE ROLE lab_event_fixture LOGIN PASSWORD '"+publisher_password+"' IN ROLE lab_event_publisher; GRANT CONNECT ON DATABASE traderx TO lab_event_fixture;")
        def publisher(query):
            return execute('lab_event_fixture', publisher_password, query)
        def claim(worker, limit=1, lease=60):
            query = f"SELECT coalesce(json_agg(t ORDER BY t.event_sequence),'[]'::json) FROM lab_execution.claim_events('{worker}',{limit},{lease}) t;"
            return json.loads(require(publisher(query), 'Event claim failed'))
        def ack(event, worker, token):
            return require(publisher(f"SELECT lab_execution.ack_event('{event}','{worker}','{token}');"), 'Event acknowledgment failed')
        def business():
            return admin("SELECT json_build_object('trades',(SELECT json_agg(t ORDER BY id) FROM trades t),'positions',(SELECT json_agg(p ORDER BY accountid,security) FROM positions p),'orders',(SELECT json_agg(o ORDER BY orderid) FROM orderbook o),'receipts',(SELECT json_agg(r ORDER BY execution_id) FROM lab_execution.receipts r));")
        admin("INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms) VALUES ('event-order',22214,'IBM','Buy',10,10,100,'NEW',now(),now(),'trader','https://identity.example.test','fixture');")
        first, second = str(uuid.uuid4()), str(uuid.uuid4())
        require(actor('order-matcher',f"SELECT lab_execution.reserve('{first}','event-order',6,99);"), 'First reservation failed')
        before = business()
        require(actor('trade-processor',f"BEGIN; SELECT lab_execution.settle('{first}'); ROLLBACK;"), 'Rollback probe failed')
        check(admin('SELECT count(*) FROM lab_execution.events;') == '0' and business() == before,
              'rollback removes events and business effects together')
        admin("CREATE FUNCTION lab_execution.test_fail_event() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'synthetic outbox failure'; END $$; CREATE TRIGGER test_fail_event BEFORE INSERT ON lab_execution.events FOR EACH ROW EXECUTE FUNCTION lab_execution.test_fail_event();")
        reject(actor('trade-processor',f"SELECT lab_execution.settle('{first}');"), 'outbox failure rejects settlement', 'P0001')
        check(admin('SELECT count(*) FROM lab_execution.events;') == '0' and business() == before,
              'outbox failure leaves no trade position order receipt or event effects')
        admin('DROP TRIGGER test_fail_event ON lab_execution.events; DROP FUNCTION lab_execution.test_fail_event();')
        with ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: actor('trade-processor', f"SELECT lab_execution.settle('{first}');"), range(2)))
        for result in results:
            if require(result, 'Concurrent settlement failed') != first:
                raise AssertionError('Wrong settlement receipt')
        check(admin('SELECT count(*) FROM lab_execution.events;') == '2', 'concurrent settlement replay creates exactly two events')
        first_snapshot = admin(f"SELECT payload::text FROM lab_execution.events WHERE event_id='{first}:position';")
        check(json.loads(first_snapshot)['quantity'] == -94, 'position event captures settlement-time quantity')
        require(actor('order-matcher',f"SELECT lab_execution.reserve('{second}','event-order',4,98);"), 'Second reservation failed')
        require(actor('trade-processor',f"SELECT lab_execution.settle('{second}');"), 'Second settlement failed')
        check(admin(f"SELECT payload::text FROM lab_execution.events WHERE event_id='{first}:position';") == first_snapshot,
              'later settlement does not mutate earlier position snapshot')
        check(json.loads(admin(f"SELECT payload::text FROM lab_execution.events WHERE event_id='{second}:position';"))['quantity'] == -90,
              'later settlement gets its own resulting position snapshot')
        check(admin(f"SELECT max(event_sequence) < (SELECT min(event_sequence) FROM lab_execution.events WHERE execution_id='{second}') FROM lab_execution.events WHERE execution_id='{first}';") == 't',
              'same-account settlement snapshots have increasing sequence numbers')
        check(admin("SELECT count(*) FROM lab_execution.events WHERE topic NOT IN ('/accounts/22214/trades','/accounts/22214/positions');") == '0',
              'event topics remain scoped to accepted account')
        reject(execute('traderx', password, EVENTS.read_text()), 'migration refuses historical receipts without backfill', 'P0001')
        baseline = business()
        worker_a, worker_b, worker_c = (str(uuid.uuid4()) for _ in range(3))
        for name in ('order-matcher', 'trade-processor', 'account-service'):
            reject(actor(name, f"SELECT * FROM lab_execution.claim_events('{worker_a}',1,60);"), name+' cannot claim publisher events', '42501')
            reject(actor(name, f"SELECT lab_execution.ack_event('{first}:trade','{worker_a}','{worker_b}');"), name+' cannot acknowledge publisher events', '42501')
        reject(publisher('UPDATE lab_execution.events SET payload=\'{}\'::jsonb;'), 'publisher cannot mutate event payload', '42501')
        reject(publisher('DELETE FROM lab_execution.events;'), 'publisher cannot delete events', '42501')
        reject(publisher('SELECT * FROM lab_execution.events;'), 'publisher cannot bypass claim function to read backlog', '42501')
        reject(publisher(f"SELECT lab_execution.settle('{first}');"), 'publisher cannot settle trades', '42501')
        for limit, lease in ((0, 60), (101, 60), (1, 0), (1, 301)):
            reject(publisher(f"SELECT * FROM lab_execution.claim_events('{worker_a}',{limit},{lease});"), f'claim bounds rejected ({limit},{lease})', '22023')
        with ThreadPoolExecutor(max_workers=2) as pool:
            batches = list(pool.map(lambda worker: claim(worker), [worker_a, worker_b]))
        rows = [batch[0] for batch in batches if len(batch) == 1]
        check(len(rows) == 2 and len({row['event_id'] for row in rows}) == 2,
              'concurrent publishers receive distinct live leases')
        row = rows[0]
        check(ack(row['event_id'], worker_b, row['lease_token']) == 'f', 'another worker cannot acknowledge a live lease')
        check(ack(row['event_id'], worker_a, str(uuid.uuid4())) == 'f', 'wrong lease token cannot acknowledge')
        check(ack(row['event_id'], worker_a, row['lease_token']) == 't', 'current worker and token acknowledge successfully')
        check(ack(row['event_id'], worker_a, row['lease_token']) == 't', 'successful acknowledgment replay is idempotent')
        row_b = rows[1]
        check(ack(row_b['event_id'], worker_b, row_b['lease_token']) == 't', 'second publisher acknowledges its event')
        # Simulate broker accepted / publisher crashed before database acknowledgment.
        lost = claim(worker_a, 1, 1)[0]
        restart()
        time.sleep(1.05)
        check(ack(lost['event_id'], worker_a, lost['lease_token']) == 'f', 'expired lease cannot acknowledge after restart')
        reclaimed = claim(worker_c, 1, 60)[0]
        check(reclaimed['event_id'] == lost['event_id'] and reclaimed['payload'] == lost['payload'],
              'unacknowledged event replays with stable ID and payload after restart')
        check(reclaimed['lease_token'] != lost['lease_token'] and reclaimed['attempts'] == 2,
              'reclaim fences old token and increments attempts')
        check(ack(lost['event_id'], worker_a, lost['lease_token']) == 'f', 'stale claim cannot acknowledge a reclaimed event')
        check(ack(reclaimed['event_id'], worker_c, reclaimed['lease_token']) == 't', 'replacement publisher acknowledges replay')
        for pending in claim(worker_c, 100, 60):
            if ack(pending['event_id'], worker_c, pending['lease_token']) != 't':
                raise AssertionError('Final event acknowledgment failed')
        check(claim(worker_a, 100, 60) == [], 'acknowledged events are not claimed again')
        check(admin('SELECT count(*) FROM lab_execution.events WHERE delivered_at IS NOT NULL;') == '4',
              'all four immutable events retained after acknowledgment')
        check(business() == baseline, 'notification retry and acknowledgment never reapply business settlement')
    return {'status':'passed','scope':'PostgreSQL transactional outbox and simulated publisher leases; no broker/consumer deployment',
            'image':image,'migration_sha256':hashlib.sha256(EVENTS.read_bytes()).hexdigest(),
            'reservation_sha256':hashlib.sha256(MIGRATION.read_bytes()).hexdigest(),
            'settlement_sha256':hashlib.sha256(SETTLEMENT.read_bytes()).hexdigest(),
            'checks':checks,'delivery_semantics':'at-least-once; durable consumer deduplication required',
            'limits':{'memory_mib':256,'cpu':1,'host_ports':0},
            'limitations':['Broker acceptance is simulated; no NATS publisher or durable broker acknowledgment is tested',
                           'Consumers must atomically deduplicate event IDs and reject stale position snapshot sequences',
                           'A compromised authorized publisher can falsely acknowledge its claims',
                           'Migration refuses existing receipts; deployed services and runtime images remain unchanged']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if args.output.exists():
        raise ValueError('Evidence already exists')
    with operation(args.runtime_dir, 'fixture'):
        result = campaign(args.runtime_dir)
    with args.output.open('x') as stream:
        json.dump(result, stream, indent=2)
        stream.write('\n')
    print('Transactional outbox and fenced event replay checks passed; broker integration remains pending.')


if __name__ == '__main__':
    main()
