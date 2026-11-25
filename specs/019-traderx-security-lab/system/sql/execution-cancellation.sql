BEGIN;
SELECT pg_advisory_xact_lock(190020);
CREATE FUNCTION lab_execution.cancel_order(p_order varchar,p_account integer) RETURNS varchar
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE o public.orderbook%ROWTYPE;
BEGIN
 SELECT * INTO o FROM public.orderbook WHERE orderid=p_order FOR UPDATE;
 IF NOT FOUND OR p_account IS NULL OR o.accountid IS DISTINCT FROM p_account THEN
  RAISE EXCEPTION 'order unavailable' USING ERRCODE='22023';
 END IF;
 IF o.status IN ('NEW','PARTIALLY_FILLED') THEN
  UPDATE public.orderbook SET status='CANCELED',remainingquantity=0,updatedat=clock_timestamp() WHERE orderid=p_order;
 END IF;
 RETURN p_order;
END $$;
REVOKE ALL ON FUNCTION lab_execution.cancel_order(varchar,integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION lab_execution.cancel_order(varchar,integer) TO lab_order_matcher;
COMMIT;
