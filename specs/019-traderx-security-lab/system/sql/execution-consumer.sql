-- Reference projection only. Existing trade/position business tables are never written.
BEGIN;
SELECT pg_advisory_xact_lock(190020);
CREATE ROLE lab_event_consumer NOLOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
GRANT USAGE ON SCHEMA lab_execution TO lab_event_consumer;
CREATE TABLE lab_execution.consumer_accounts (
 login_role name NOT NULL, account_id integer NOT NULL, PRIMARY KEY(login_role,account_id)
);
CREATE TABLE lab_execution.consumer_inbox (
 login_role name NOT NULL, event_id varchar(48) NOT NULL,
 envelope jsonb NOT NULL, applied_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(login_role,event_id)
);
CREATE TABLE lab_execution.trade_projection (
 login_role name NOT NULL, event_id varchar(48) NOT NULL, payload jsonb NOT NULL,
 PRIMARY KEY(login_role,event_id)
);
CREATE TABLE lab_execution.position_projection (
 login_role name NOT NULL, account_id integer NOT NULL, security varchar(16) NOT NULL,
 event_sequence bigint NOT NULL CHECK(event_sequence>0), payload jsonb NOT NULL,
 PRIMARY KEY(login_role,account_id,security)
);
REVOKE ALL ON lab_execution.consumer_accounts,lab_execution.consumer_inbox,
 lab_execution.trade_projection,lab_execution.position_projection FROM PUBLIC,lab_event_consumer,lab_event_publisher;

CREATE FUNCTION lab_execution.consume_event(p_topic text,p_envelope jsonb) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE e lab_execution.events%ROWTYPE; inserted integer; changed integer;
BEGIN
 SELECT * INTO e FROM lab_execution.events WHERE event_id=p_envelope->>'eventId';
 IF NOT FOUND OR p_topic IS DISTINCT FROM e.topic OR NOT EXISTS (
   SELECT FROM lab_execution.consumer_accounts a
   WHERE a.login_role=session_user AND a.account_id=(e.payload->>'accountId')::integer
 ) THEN RAISE EXCEPTION 'event unavailable' USING ERRCODE='22023'; END IF;
 IF p_envelope IS DISTINCT FROM jsonb_build_object('eventId',e.event_id,
   'eventSequence',e.event_sequence,'executionId',e.execution_id,
   'eventKind',e.event_kind,'payload',e.payload) THEN
   RAISE EXCEPTION 'event unavailable' USING ERRCODE='22023';
 END IF;
 INSERT INTO lab_execution.consumer_inbox(login_role,event_id,envelope)
 VALUES(session_user,e.event_id,p_envelope) ON CONFLICT DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted=0 THEN RETURN 'duplicate'; END IF;
 IF e.event_kind='trade.settled' THEN
   INSERT INTO lab_execution.trade_projection(login_role,event_id,payload)
   VALUES(session_user,e.event_id,e.payload);
 ELSE
   INSERT INTO lab_execution.position_projection(login_role,account_id,security,event_sequence,payload)
   VALUES(session_user,(e.payload->>'accountId')::integer,e.payload->>'security',e.event_sequence,e.payload)
   ON CONFLICT(login_role,account_id,security) DO UPDATE
   SET event_sequence=EXCLUDED.event_sequence,payload=EXCLUDED.payload
   WHERE lab_execution.position_projection.event_sequence<EXCLUDED.event_sequence;
   GET DIAGNOSTICS changed=ROW_COUNT;
   IF changed=0 THEN RETURN 'stale'; END IF;
 END IF;
 RETURN 'applied';
END $$;
REVOKE ALL ON FUNCTION lab_execution.consume_event(text,jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lab_execution.consume_event(text,jsonb) TO lab_event_consumer;
COMMIT;
