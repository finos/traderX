import os
import re
import sqlite3
import unittest

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

class TestSeam1PostgresDDL(unittest.TestCase):
    def test_templates_schema_contains_nullable_limitprice_and_ordertype(self):
        paths = [
            os.path.join(REPO_ROOT, 'templates', 'database-specfirst', 'initialSchema.sql'),
            os.path.join(REPO_ROOT, 'templates', 'state-010-pricing-awareness-market-data-overlay', 'database', 'initialSchema.sql')
        ]
        for p in paths:
            with self.subTest(path=p):
                with open(p, 'r', encoding='utf-8') as f:
                    content = f.read()
                
                # Verify limitprice is nullable (does not have NOT NULL)
                match_lp = re.search(r'LimitPrice\s+DECIMAL\(18,3\)(.*?),', content, re.IGNORECASE)
                self.assertIsNotNone(match_lp, f'LimitPrice not found in {p}')
                lp_suffix = match_lp.group(1).strip()
                self.assertNotIn('not null', lp_suffix.lower(), f'LimitPrice must be nullable in {p}')
                
                # Verify ordertype column exists with CHECK constraint and default 'LIMIT'
                match_ot = re.search(r'OrderType\s+VARCHAR\(20\)(.*?),', content, re.IGNORECASE)
                if not match_ot:
                    match_ot = re.search(r'OrderType\s+VARCHAR\(20\)(.*?)\n', content, re.IGNORECASE)
                self.assertIsNotNone(match_ot, f'OrderType column not found in {p}')
                ot_def = match_ot.group(1)
                self.assertIn('limit', ot_def.lower())
                self.assertIn('market', ot_def.lower())

    def test_patch_hunk_contains_nullable_limitprice_and_ordertype(self):
        patch_path = os.path.join(REPO_ROOT, 'specs', '009-order-management-matcher', 'generation', 'patches', '0001-state-overlay.patch')
        with open(patch_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        self.assertIn('+  limitprice DECIMAL(18,3),', content)
        self.assertIn("+  ordertype VARCHAR(20) NOT NULL DEFAULT 'LIMIT' CHECK (ordertype in ('LIMIT', 'MARKET'))", content)

    def test_ddl_behavior_in_sqlite(self):
        conn = sqlite3.connect(':memory:')
        cur = conn.cursor()
        cur.execute("""
            CREATE TABLE orderbook (
                orderid VARCHAR(32) PRIMARY KEY,
                accountid INTEGER NOT NULL,
                security VARCHAR(16) NOT NULL,
                side VARCHAR(16) CHECK (side in ('Buy', 'Sell')),
                quantity INTEGER NOT NULL CHECK (quantity > 0),
                remainingquantity INTEGER NOT NULL CHECK (remainingquantity >= 0),
                limitprice DECIMAL(18,3),
                status VARCHAR(24) CHECK (status in ('NEW', 'PARTIALLY_FILLED', 'FILLED', 'CANCELED', 'REJECTED')),
                createdat TIMESTAMP NOT NULL,
                updatedat TIMESTAMP NOT NULL,
                lastexecutionprice DECIMAL(18,3),
                lastfillquantity INTEGER,
                ordertype VARCHAR(20) NOT NULL DEFAULT 'LIMIT' CHECK (ordertype in ('LIMIT', 'MARKET'))
            )
        """)
        
        # 1. LIMIT order with price: should succeed
        cur.execute("""
            INSERT INTO orderbook VALUES ('ord-1', 1, 'AAPL', 'Buy', 10, 10, 150.0, 'NEW', '2026-11-13 00:00:00', '2026-11-13 00:00:00', NULL, NULL, 'LIMIT')
        """)
        
        # 2. MARKET order with NULL limit price: should succeed
        cur.execute("""
            INSERT INTO orderbook VALUES ('ord-2', 1, 'AAPL', 'Buy', 10, 10, NULL, 'NEW', '2026-11-13 00:00:00', '2026-11-13 00:00:00', NULL, NULL, 'MARKET')
        """)
        
        # 3. MARKET order with limit price: should succeed
        cur.execute("""
            INSERT INTO orderbook VALUES ('ord-3', 1, 'AAPL', 'Buy', 10, 10, 155.0, 'NEW', '2026-11-13 00:00:00', '2026-11-13 00:00:00', NULL, NULL, 'MARKET')
        """)
        
        # 4. Default ordertype: should default to LIMIT
        cur.execute("""
            INSERT INTO orderbook (orderid, accountid, security, side, quantity, remainingquantity, limitprice, status, createdat, updatedat)
            VALUES ('ord-4', 1, 'AAPL', 'Buy', 10, 10, 160.0, 'NEW', '2026-11-13 00:00:00', '2026-11-13 00:00:00')
        """)
        cur.execute("SELECT ordertype FROM orderbook WHERE orderid = 'ord-4'")
        self.assertEqual(cur.fetchone()[0], 'LIMIT')
        
        # 5. Invalid ordertype: should fail check constraint
        with self.assertRaises(sqlite3.IntegrityError):
            cur.execute("""
                INSERT INTO orderbook VALUES ('ord-5', 1, 'AAPL', 'Buy', 10, 10, 150.0, 'NEW', '2026-11-13 00:00:00', '2026-11-13 00:00:00', NULL, NULL, 'STOP_LOSS')
            """)
        
        conn.close()

if __name__ == '__main__':
    unittest.main()
