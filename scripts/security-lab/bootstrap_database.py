"""Fresh synthetic C3 database initialization; never a migration or reset mechanism."""
import re
import secrets

import database_permissions
import lab
import prepare_runtime

SEED_TIME = '2026-01-01 00:00:00'


def seed_sql(reference):
    matches = [d for d in reference['items'] if d['kind'] == 'ConfigMap' and d['metadata']['name'] == 'database-init-sql']
    if len(matches) != 1 or set(matches[0]['data']) != {'001-initialSchema.sql'}:
        raise ValueError('Unreviewed seed configuration')
    source = matches[0]['data']['001-initialSchema.sql']
    # The pinned reference script drops its old tables; a fresh bootstrap must never do that.
    lines = source.splitlines()
    drops = [line for line in lines if line.startswith('DROP ')]
    expected = {f'DROP TABLE IF EXISTS {t};' for t in ('trades','orderbook','accountusers','positions','accounts')}
    expected.add('DROP SEQUENCE IF EXISTS accounts_seq;')
    if set(drops) != expected or len(drops) != len(expected):
        raise ValueError('Pinned seed reset preamble changed')
    body = '\n'.join(line for line in lines if not line.startswith('DROP '))
    if re.search(r'\b(DROP|TRUNCATE|BEGIN|COMMIT|ROLLBACK|ALTER\s+ROLE)\b|^\s*\\', body, re.I | re.M):
        raise ValueError('Unreviewed bootstrap SQL statement')
    return body.replace('NOW()', "TIMESTAMP '" + SEED_TIME + "'").strip() + '\n'


def credentials():
    return {name: {'username': grant['role'], 'password': secrets.token_hex(24)}
            for name, grant in database_permissions.GRANTS.items()}


def render(reference, identities):
    if set(identities) != set(database_permissions.GRANTS):
        raise ValueError('Exactly four runtime identities required')
    grants = database_permissions.grant_sql(identities)
    if not grants.startswith('BEGIN;\n') or not grants.endswith('COMMIT;\n'):
        raise ValueError('Grant transaction contract changed')
    roles = ','.join("'"+g['role']+"'" for g in database_permissions.GRANTS.values())
    return f'''BEGIN;
SELECT pg_advisory_xact_lock(190019);
DO $$ BEGIN
  IF current_database() <> 'traderx' THEN
    RAISE EXCEPTION 'Bootstrap requires the isolated traderx database';
  END IF;
  IF EXISTS (SELECT FROM pg_class WHERE relnamespace='public'::regnamespace)
     OR EXISTS (SELECT FROM pg_proc WHERE pronamespace='public'::regnamespace)
     OR EXISTS (SELECT FROM pg_type WHERE typnamespace='public'::regnamespace)
     OR EXISTS (SELECT FROM pg_namespace WHERE nspname NOT IN ('public','pg_catalog','information_schema') AND nspname NOT LIKE 'pg_%')
     OR EXISTS (SELECT FROM pg_roles WHERE rolname IN ({roles})) THEN
    RAISE EXCEPTION 'Bootstrap refuses existing public objects or runtime roles';
  END IF;
END $$;
{seed_sql(reference)}
{grants[len('BEGIN;\n'):-len('COMMIT;\n')]}
COMMIT;
'''


def pinned_reference():
    return prepare_runtime.render_reference(lab.read_json(lab.PROFILE/'baseline.lock.json'),
        lab.read_json(lab.PROFILE/'runtime-images.lock.json'), offline=True)
