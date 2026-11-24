-- Candidate-only transaction boundary; not invoked by the deployed processor.
BEGIN;
SELECT pg_advisory_xact_lock(190020);
CREATE FUNCTION lab_execution.settle(p_id uuid) RETURNS varchar
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE r lab_execution.reservations%ROWTYPE; o public.orderbook%ROWTYPE;
 prior varchar; old_qty integer; old_avg numeric; signed_qty integer; new_qty integer; new_avg numeric;
BEGIN
 SELECT * INTO r FROM lab_execution.reservations WHERE execution_id=p_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'unknown execution' USING ERRCODE='22023'; END IF;
 SELECT * INTO o FROM public.orderbook WHERE orderid=r.order_id FOR UPDATE;
 SELECT trade_id INTO prior FROM lab_execution.receipts WHERE execution_id=p_id;
 IF FOUND THEN RETURN prior; END IF;
 IF o.status IS NULL OR o.remainingquantity IS NULL OR o.status NOT IN ('NEW','PARTIALLY_FILLED') OR o.remainingquantity<r.quantity
    OR o.accountid IS DISTINCT FROM r.account_id OR o.security IS DISTINCT FROM r.security
    OR o.side IS DISTINCT FROM r.side OR o.acceptedsubject IS DISTINCT FROM r.accepted_subject
    OR o.acceptedissuer IS DISTINCT FROM r.accepted_issuer OR o.acceptedterms IS DISTINCT FROM r.accepted_terms
    OR (o.side='Buy' AND r.price>o.limitprice) OR (o.side='Sell' AND r.price<o.limitprice) THEN
   RAISE EXCEPTION 'order changed or canceled' USING ERRCODE='22023';
 END IF;
 -- Serializes absent as well as existing position rows for this account.
 PERFORM 1 FROM public.accounts WHERE id=r.account_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'unknown account' USING ERRCODE='22023'; END IF;
 SELECT quantity,averagecostbasis INTO old_qty,old_avg FROM public.positions
   WHERE accountid=r.account_id AND security=r.security FOR UPDATE;
 old_qty:=coalesce(old_qty,0); old_avg:=coalesce(old_avg,0);
 signed_qty:=CASE WHEN r.side='Buy' THEN r.quantity ELSE -r.quantity END;
 new_qty:=old_qty+signed_qty;
 new_avg:=CASE WHEN new_qty=0 THEN 0 ELSE round((old_avg*old_qty+r.price*signed_qty)/new_qty,3) END;
 INSERT INTO public.trades(id,accountid,security,side,quantity,price,created,updated,state)
 VALUES(p_id::text,r.account_id,r.security,r.side,r.quantity,r.price,clock_timestamp(),clock_timestamp(),'Settled');
 INSERT INTO public.positions(accountid,security,quantity,averagecostbasis,updated)
 VALUES(r.account_id,r.security,new_qty,new_avg,clock_timestamp())
 ON CONFLICT(accountid,security) DO UPDATE SET quantity=excluded.quantity,
 averagecostbasis=excluded.averagecostbasis,updated=excluded.updated;
 UPDATE public.orderbook SET remainingquantity=remainingquantity-r.quantity,
 status=CASE WHEN remainingquantity=r.quantity THEN 'FILLED' ELSE 'PARTIALLY_FILLED' END,
 lastexecutionprice=r.price,lastfillquantity=r.quantity,updatedat=clock_timestamp() WHERE orderid=r.order_id;
 INSERT INTO lab_execution.receipts(execution_id,trade_id) VALUES(p_id,p_id::text);
 RETURN p_id::text;
END $$;
REVOKE ALL ON FUNCTION lab_execution.settle(uuid) FROM PUBLIC;
GRANT USAGE ON SCHEMA lab_execution TO lab_trade_processor;
GRANT SELECT ON lab_execution.receipts TO lab_order_matcher,lab_trade_processor;
GRANT EXECUTE ON FUNCTION lab_execution.settle(uuid) TO lab_trade_processor;
COMMIT;
