"""Independent bounded SQL adversarial campaign; never a deployed-state acceptance test."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import time
import uuid

import bootstrap_database
from resource_operation import operation
from verify_bootstrap import database, require

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_SQL = ROOT / 'specs/019-traderx-security-lab/system/sql'


def ensure(condition, message):
    if not condition:
        raise RuntimeError(message)


def campaign(runtime, sql_dir=DEFAULT_SQL):
    paths = [sql_dir / name for name in ('execution-reservations.sql', 'execution-settlement.sql')]
    cancellation = sql_dir / 'execution-cancellation.sql'
    if cancellation.exists():
        paths.append(cancellation)
    reference = bootstrap_database.pinned_reference()
    image = next(d for d in reference['items'] if d['kind'] == 'Deployment' and d['metadata']['name'] == 'database')['spec']['template']['spec']['containers'][0]['image']
    identities = bootstrap_database.credentials()
    checks, findings = [], []
    with database(runtime, image, persistent=True) as (execute, password, restart):
        def admin(statement):
            return require(execute('traderx', password, statement), 'Adversarial fixture setup/read failed')

        def as_role(service, statement):
            identity = identities[service]
            return execute(identity['username'], identity['password'], statement)

        def matcher(statement):
            return as_role('order-matcher', statement)

        def processor(statement):
            return as_role('trade-processor', statement)

        def rejected(result, label, state='22023'):
            ensure(result.returncode != 0 and state in result.stderr, label + ': expected SQL rejection missing')
            checks.append(label)

        admin(bootstrap_database.render(reference, identities))
        for path in paths:
            admin(path.read_text())

        def order(name, quantity=10):
            # Fixed caller-owned synthetic inputs only; never accepts arbitrary SQL from a learner.
            admin(f"""INSERT INTO orderbook(orderid,accountid,security,side,quantity,remainingquantity,limitprice,status,createdat,updatedat,acceptedsubject,acceptedissuer,acceptedterms)
              VALUES ('{name}',22214,'IBM','Buy',{quantity},{quantity},100,'NEW',now(),now(),'synthetic-trader','https://identity.example.test','{name}|22214|IBM|Buy|{quantity}|100');""")

        def reserve(name, quantity=6, identifier=None):
            identifier = identifier or str(uuid.uuid4())
            result = matcher(f"SELECT lab_execution.reserve('{identifier}','{name}',{quantity},99);")
            ensure(require(result, 'Reservation setup failed') == identifier, 'Unexpected reservation identity')
            return identifier

        def settle(identifier):
            return f"SELECT lab_execution.settle('{identifier}');"

        def effects(identifier):
            return admin(f"""SELECT json_build_object(
              'trade',(SELECT count(*) FROM trades WHERE id='{identifier}'),
              'receipt',(SELECT count(*) FROM lab_execution.receipts WHERE execution_id='{identifier}'),
              'position',(SELECT quantity FROM positions WHERE accountid=22214 AND security='IBM'))::text;""")

        # A changed authority/account snapshot must be denied with no trade/receipt/position effects.
        order('adv-substitute')
        identifier = reserve('adv-substitute')
        before = effects(identifier)
        variants = [
            ('accountid=44044', 'accountid=22214', 'reserved account substitution denied'),
            ("security='MSFT'", "security='IBM'", 'reserved security substitution denied'),
            ("side='Sell'", "side='Buy'", 'reserved side substitution denied'),
            ("acceptedsubject='other'", "acceptedsubject='synthetic-trader'", 'accepting subject substitution denied'),
            ("acceptedissuer='https://other.example.test'", "acceptedissuer='https://identity.example.test'", 'accepting issuer substitution denied'),
            ("acceptedterms='changed'", "acceptedterms='adv-substitute|22214|IBM|Buy|10|100'", 'accepted terms substitution denied'),
            ("status=NULL", "status='NEW'", 'null order status denied'),
        ]
        for change, restore, label in variants:
            require(matcher(f"UPDATE orderbook SET {change} WHERE orderid='adv-substitute';"), 'Synthetic mutation failed')
            rejected(processor(settle(identifier)), label)
            ensure(effects(identifier) == before, label + ': business effects changed')
            require(matcher(f"UPDATE orderbook SET {restore} WHERE orderid='adv-substitute';"), 'Synthetic restoration failed')

        # Rollback/unknown delivery outcome are tested by resulting state, not a response alone.
        require(processor('BEGIN; ' + settle(identifier) + ' ROLLBACK;'), 'Rollback execution failed')
        ensure(effects(identifier) == before, 'Rollback left business effects')
        checks.append('rollback removes trade receipt and position effects')
        # Intentionally discard this successful response to model an unknown response outcome.
        delivered = processor(settle(identifier))
        ensure(delivered.returncode == 0, 'Initial delivery failed')
        committed = effects(identifier)
        restart()
        for _ in range(3):
            require(processor(settle(identifier)), 'Retry after ambiguous response failed')
        ensure(effects(identifier) == committed, 'Retry after unknown response duplicated effects')
        ensure(json.loads(committed)['trade'] == json.loads(committed)['receipt'] == 1, 'Missing durable effect pair')
        checks.append('discarded response and database restart replay have no duplicate effects')

        order('adv-replay-other')
        rejected(matcher(f"SELECT lab_execution.reserve('{identifier}','adv-replay-other',6,99);"), 'execution ID replay across orders denied')
        rejected(matcher(f"SELECT lab_execution.reserve('{identifier}','adv-substitute',5,99);"), 'execution ID replay with changed quantity denied')
        rejected(matcher(f"SELECT lab_execution.reserve('{identifier}','adv-substitute',6,98);"), 'execution ID replay with changed price denied')
        ensure(effects(identifier) == committed, 'Conflicting replay changed settled effects')

        # Supported application cancellation must share SQL settlement's lock, not just a JVM lock.
        has_cancel = admin("SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='lab_execution' AND p.proname='cancel_order';") == '1'
        if has_cancel:
            def cancel(name, account=22214):
                return f"SELECT lab_execution.cancel_order('{name}',{account});"

            def waiting(tag, event):
                deadline = time.monotonic() + 8
                while time.monotonic() < deadline:
                    if admin(f"SELECT count(*) FROM pg_stat_activity WHERE application_name='{tag}' AND wait_event_type='{event}';") == '1':
                        return
                    time.sleep(.05)
                raise RuntimeError('Expected transaction coordination point not observed')

            order('adv-cancel-first')
            canceled = reserve('adv-cancel-first', 10)
            untouched = effects(canceled)
            with ThreadPoolExecutor(max_workers=2) as pool:
                first = pool.submit(matcher, "SET application_name='adv-cancel-first'; BEGIN; " + cancel('adv-cancel-first') + " SELECT pg_sleep(2); COMMIT;")
                waiting('adv-cancel-first', 'Timeout')
                second = pool.submit(processor, "SET application_name='adv-settle-waits'; " + settle(canceled))
                waiting('adv-settle-waits', 'Lock')
                require(first.result(), 'Winning cancellation failed')
                rejected(second.result(), 'cancel-first race prevents settlement')
            ensure(effects(canceled) == untouched, 'Cancellation race changed business effects')

            order('adv-settle-first')
            filled = reserve('adv-settle-first', 10)
            with ThreadPoolExecutor(max_workers=2) as pool:
                first = pool.submit(processor, "SET application_name='adv-settle-first'; BEGIN; " + settle(filled) + " SELECT pg_sleep(2); COMMIT;")
                waiting('adv-settle-first', 'Timeout')
                second = pool.submit(matcher, "SET application_name='adv-cancel-waits'; " + cancel('adv-settle-first'))
                waiting('adv-cancel-waits', 'Lock')
                require(first.result(), 'Winning settlement failed')
                require(second.result(), 'Cancellation after settlement failed')
            ensure(admin("SELECT status||'|'||remainingquantity||'|'||lastfillquantity FROM orderbook WHERE orderid='adv-settle-first';") == 'FILLED|0|10', 'Settled fill overwritten by cancellation')
            checks.append('settle-first race preserves full fill and receipt')

            order('adv-partial-cancel')
            partial = reserve('adv-partial-cancel', 6)
            require(processor(settle(partial)), 'Partial settlement failed')
            partial_effects = effects(partial)
            rejected(matcher(cancel('adv-partial-cancel', 44044)), 'cross-account cancellation denied')
            require(matcher(cancel('adv-partial-cancel')), 'Partial cancellation failed')
            ensure(admin("SELECT status||'|'||remainingquantity||'|'||lastfillquantity FROM orderbook WHERE orderid='adv-partial-cancel';") == 'CANCELED|0|6', 'Partial fill metadata lost during cancellation')
            ensure(effects(partial) == partial_effects, 'Cancellation changed committed trade/position')
            checks.append('partial fill survives cancellation of remainder')
        else:
            findings.append({'id':'ADV-CANCEL-01','classification':'integration-blocker','severity':'high before cutover',
                'observation':'No shared-lock SQL cancellation function is present; existing Java read/save path has not been accepted against settlement concurrency.'})

        # A compromised matcher can still use its explicitly granted orderbook UPDATE permission.
        order('adv-stale-writer')
        stale = reserve('adv-stale-writer', 6)
        require(processor(settle(stale)), 'Stale-writer setup settlement failed')
        settled_effects = effects(stale)
        require(matcher("UPDATE orderbook SET status='CANCELED',remainingquantity=0,lastfillquantity=NULL,lastexecutionprice=NULL WHERE orderid='adv-stale-writer';"), 'Granted writer demonstration failed')
        ensure(admin("SELECT lastfillquantity IS NULL FROM orderbook WHERE orderid='adv-stale-writer';") == 't', 'Residual writer behavior changed')
        ensure(effects(stale) == settled_effects, 'Residual metadata write changed settled ledger')
        findings.append({'id':'ADV-WRITER-01','classification':'documented-residual-authority','severity':'scenario-dependent',
            'observation':'Matcher SQL identity can overwrite order metadata through its existing UPDATE grant. Shared-lock cancellation prevents the ordinary application race only; it does not prevent a compromised writer from bypassing that path.'})

    return {'status':('incomplete' if any(f['classification']=='integration-blocker' for f in findings) else 'passed-with-findings'),'scope':'Independent PostgreSQL effects and locking; no HTTP/Keycloak/browser campaign',
        'source_sql':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths},'image':image,'checks':checks,'findings':findings,
        'limits':{'memory_mib':256,'cpu':1,'host_ports':0},
        'limitations':['Discarded successful response models ambiguous delivery; no real network fault was injected.',
          'Credential expiry and forged service tokens are covered by existing Java/HTTP campaigns, not re-proven here.',
          'Mutation tests use the scoped matcher login against synthetic records; they do not demonstrate a real RCE.',
          'No full-cluster, broker, operator UI or live identity-provider acceptance is claimed.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--sql-dir',type=Path,default=DEFAULT_SQL)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence output already exists')
    with operation(args.runtime_dir,'fixture'):
        result=campaign(args.runtime_dir,args.sql_dir.resolve())
    with args.output.open('x') as stream:json.dump(result,stream,indent=2);stream.write('\n')
    print('Independent adversarial SQL campaign completed; review findings and scope in evidence.')
    if result['status']=='incomplete':raise SystemExit(2)

if __name__=='__main__':main()
