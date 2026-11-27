-- Candidate-only bootstrap migration. Apply once as bootstrap, never as an application login.
BEGIN;
SELECT pg_advisory_xact_lock(190020);
ALTER TABLE public.orderbook ADD COLUMN acceptedsubject varchar(255),
 ADD COLUMN acceptedissuer varchar(512), ADD COLUMN acceptedterms varchar(512);
CREATE SCHEMA lab_execution;
REVOKE ALL ON SCHEMA lab_execution FROM PUBLIC;
CREATE TABLE lab_execution.reservations (
 execution_id uuid PRIMARY KEY,
 order_id varchar(32) NOT NULL REFERENCES public.orderbook(orderid),
 account_id integer NOT NULL,
 security varchar(16) NOT NULL,
 side varchar(16) NOT NULL CHECK(side IN ('Buy','Sell')),
 quantity integer NOT NULL CHECK(quantity > 0),
 price numeric(18,3) NOT NULL CHECK(price > 0),
 accepted_subject varchar(255) NOT NULL,
 accepted_issuer varchar(512) NOT NULL,
 accepted_terms varchar(512) NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON lab_execution.reservations FROM PUBLIC;
CREATE TABLE lab_execution.receipts (
 execution_id uuid PRIMARY KEY REFERENCES lab_execution.reservations(execution_id),
 trade_id varchar(50) NOT NULL UNIQUE REFERENCES public.trades(id),
 settled_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
REVOKE ALL ON lab_execution.receipts FROM PUBLIC;
-- No state-transition or delete grant: unresolved sends continue reserving quantity.
CREATE FUNCTION lab_execution.reserve(p_id uuid,p_order varchar,p_quantity integer,p_price numeric)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
DECLARE o public.orderbook%ROWTYPE; prior lab_execution.reservations%ROWTYPE; reserved bigint;
BEGIN
 IF p_id IS NULL OR p_order IS NULL OR p_quantity IS NULL OR p_quantity <= 0
    OR p_price IS NULL OR p_price <= 0 OR p_price <> round(p_price,3)
    OR p_price::text IN ('NaN','Infinity','-Infinity') THEN
   RAISE EXCEPTION 'invalid execution request' USING ERRCODE='22023';
 END IF;
 -- All reservations for an order serialize on the owning row, including concurrent retries.
 SELECT * INTO o FROM public.orderbook WHERE orderid=p_order FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'order unavailable' USING ERRCODE='22023'; END IF;
 SELECT * INTO prior FROM lab_execution.reservations WHERE execution_id=p_id;
 IF FOUND THEN
   IF prior.order_id <> p_order OR prior.quantity <> p_quantity OR prior.price <> p_price THEN
     RAISE EXCEPTION 'execution identifier conflict' USING ERRCODE='22023';
   END IF;
   RETURN p_id; -- Retrieval only: does not authorize another downstream send.
 END IF;
 IF o.status IS NULL OR o.remainingquantity IS NULL OR o.status NOT IN ('NEW','PARTIALLY_FILLED') OR o.remainingquantity <= 0
    OR o.acceptedsubject IS NULL OR o.acceptedsubject = ''
    OR o.acceptedissuer IS NULL OR o.acceptedissuer = ''
    OR o.acceptedterms IS NULL OR o.acceptedterms = ''
    OR o.remainingquantity > o.quantity THEN
   RAISE EXCEPTION 'order not eligible' USING ERRCODE='22023';
 END IF;
 IF (o.side='Buy' AND p_price>o.limitprice) OR (o.side='Sell' AND p_price<o.limitprice) THEN
   RAISE EXCEPTION 'outside limit price' USING ERRCODE='22023';
 END IF;
 SELECT coalesce(sum(quantity),0) INTO reserved FROM lab_execution.reservations WHERE order_id=p_order AND NOT EXISTS (SELECT FROM lab_execution.receipts r WHERE r.execution_id=reservations.execution_id);
 IF reserved + p_quantity > o.remainingquantity THEN
   RAISE EXCEPTION 'quantity already reserved' USING ERRCODE='22023';
 END IF;
 INSERT INTO lab_execution.reservations(execution_id,order_id,account_id,security,side,quantity,price,accepted_subject,accepted_issuer,accepted_terms)
 VALUES(p_id,o.orderid,o.accountid,o.security,o.side,p_quantity,p_price,o.acceptedsubject,o.acceptedissuer,o.acceptedterms);
 RETURN p_id;
END $$;
REVOKE ALL ON FUNCTION lab_execution.reserve(uuid,varchar,integer,numeric) FROM PUBLIC;
GRANT USAGE ON SCHEMA lab_execution TO lab_order_matcher;
GRANT SELECT ON lab_execution.reservations TO lab_order_matcher;
GRANT EXECUTE ON FUNCTION lab_execution.reserve(uuid,varchar,integer,numeric) TO lab_order_matcher;
COMMIT;
