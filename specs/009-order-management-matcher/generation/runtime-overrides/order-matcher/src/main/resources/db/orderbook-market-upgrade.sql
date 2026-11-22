-- Executed by Spring SQL initialization before Hibernate schema update.
-- A single PostgreSQL statement makes the upgrade atomic. Repeated startup is safe.
DO $$
BEGIN
    IF to_regclass('orderbook') IS NOT NULL THEN
        LOCK TABLE orderbook IN ACCESS EXCLUSIVE MODE;
        ALTER TABLE orderbook ADD COLUMN IF NOT EXISTS ordertype VARCHAR(20);
        UPDATE orderbook SET ordertype = 'LIMIT' WHERE ordertype IS NULL;
        ALTER TABLE orderbook ALTER COLUMN ordertype SET DEFAULT 'LIMIT';
        ALTER TABLE orderbook ALTER COLUMN ordertype SET NOT NULL;
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conrelid = 'orderbook'::regclass
              AND conname = 'orderbook_ordertype_check'
        ) THEN
            ALTER TABLE orderbook ADD CONSTRAINT orderbook_ordertype_check
                CHECK (ordertype IN ('LIMIT', 'MARKET'));
        END IF;
        ALTER TABLE orderbook ALTER COLUMN limitprice DROP NOT NULL;
    END IF;
END
$$
^^^
