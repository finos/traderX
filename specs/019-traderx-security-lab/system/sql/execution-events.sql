-- Candidate-only transactional event outbox. Install before the first settlement.
BEGIN;
SELECT pg_advisory_xact_lock(190020);
DO $$ BEGIN
 IF EXISTS (SELECT FROM lab_execution.receipts) THEN
   RAISE EXCEPTION 'Cannot reconstruct historical position snapshots; install before settlement';
 END IF;
END $$;
CREATE ROLE lab_event_publisher NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
GRANT USAGE ON SCHEMA lab_execution TO lab_event_publisher;
CREATE TABLE lab_execution.events (
 event_id varchar(48) PRIMARY KEY,
 event_sequence bigint GENERATED ALWAYS AS IDENTITY UNIQUE NOT NULL,
 execution_id uuid NOT NULL REFERENCES lab_execution.receipts(execution_id),
 event_kind varchar(24) NOT NULL CHECK(event_kind IN ('trade.settled','position.updated')),
 topic text NOT NULL,
 payload jsonb NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 attempts bigint NOT NULL DEFAULT 0 CHECK(attempts>=0),
 claimed_by uuid,
 lease_token uuid,
 lease_until timestamptz,
 delivered_at timestamptz,
 UNIQUE(execution_id,event_kind)
);
CREATE INDEX execution_events_pending ON lab_execution.events(event_sequence) WHERE delivered_at IS NULL;
REVOKE ALL ON lab_execution.events FROM PUBLIC,lab_order_matcher,lab_trade_processor;

CREATE FUNCTION lab_execution.enqueue_settlement_events() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.trades%ROWTYPE; p public.positions%ROWTYPE;
BEGIN
 SELECT * INTO STRICT t FROM public.trades WHERE id=NEW.trade_id;
 SELECT * INTO STRICT p FROM public.positions WHERE accountid=t.accountid AND security=t.security;
 INSERT INTO lab_execution.events(event_id,execution_id,event_kind,topic,payload) VALUES
 (NEW.execution_id::text||':trade',NEW.execution_id,'trade.settled','/accounts/'||t.accountid||'/trades',
  jsonb_build_object('id',t.id,'accountId',t.accountid,'security',t.security,'side',t.side,
    'quantity',t.quantity,'price',t.price,'state',t.state,'created',t.created,'updated',t.updated)),
 (NEW.execution_id::text||':position',NEW.execution_id,'position.updated','/accounts/'||t.accountid||'/positions',
  jsonb_build_object('accountId',p.accountid,'security',p.security,'quantity',p.quantity,
    'averageCostBasis',p.averagecostbasis,'updated',p.updated));
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION lab_execution.enqueue_settlement_events() FROM PUBLIC;
CREATE TRIGGER execution_receipt_events AFTER INSERT ON lab_execution.receipts
 FOR EACH ROW EXECUTE FUNCTION lab_execution.enqueue_settlement_events();

-- A committed claim does not mark an event delivered. Crash/timeout permits replay.
CREATE FUNCTION lab_execution.claim_events(p_worker uuid,p_limit integer,p_lease_seconds integer)
RETURNS TABLE(event_id varchar,event_sequence bigint,execution_id uuid,event_kind varchar,
 topic text,payload jsonb,lease_token uuid,lease_until timestamptz,attempts bigint)
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
BEGIN
 IF p_worker IS NULL OR p_limit IS NULL OR p_limit<1 OR p_limit>100
    OR p_lease_seconds IS NULL OR p_lease_seconds<1 OR p_lease_seconds>300 THEN
   RAISE EXCEPTION 'Invalid event claim' USING ERRCODE='22023';
 END IF;
 RETURN QUERY
 WITH candidates AS (
   SELECT e.event_id FROM lab_execution.events e WHERE e.delivered_at IS NULL
     AND (e.lease_until IS NULL OR e.lease_until<=clock_timestamp())
   ORDER BY e.event_sequence FOR UPDATE SKIP LOCKED LIMIT p_limit
 )
 UPDATE lab_execution.events e SET claimed_by=p_worker,lease_token=gen_random_uuid(),
   lease_until=clock_timestamp()+make_interval(secs=>p_lease_seconds),attempts=e.attempts+1
 FROM candidates c WHERE e.event_id=c.event_id
 RETURNING e.event_id,e.event_sequence,e.execution_id,e.event_kind,e.topic,e.payload,
   e.lease_token,e.lease_until,e.attempts;
END $$;
REVOKE ALL ON FUNCTION lab_execution.claim_events(uuid,integer,integer) FROM PUBLIC;

CREATE FUNCTION lab_execution.ack_event(p_event varchar,p_worker uuid,p_token uuid)
RETURNS boolean LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE e lab_execution.events%ROWTYPE;
BEGIN
 SELECT * INTO e FROM lab_execution.events WHERE event_id=p_event FOR UPDATE;
 IF NOT FOUND OR e.claimed_by IS DISTINCT FROM p_worker OR e.lease_token IS DISTINCT FROM p_token
    OR p_worker IS NULL OR p_token IS NULL THEN RETURN false; END IF;
 -- Retry of the successful acknowledgment itself is harmless.
 IF e.delivered_at IS NOT NULL THEN RETURN true; END IF;
 IF e.lease_until IS NULL OR e.lease_until<=clock_timestamp() THEN RETURN false; END IF;
 UPDATE lab_execution.events SET delivered_at=clock_timestamp() WHERE event_id=p_event;
 RETURN true;
END $$;
REVOKE ALL ON FUNCTION lab_execution.ack_event(varchar,uuid,uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lab_execution.claim_events(uuid,integer,integer),
 lab_execution.ack_event(varchar,uuid,uuid) TO lab_event_publisher;
COMMIT;
