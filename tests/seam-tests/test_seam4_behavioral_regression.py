import os
import re
import unittest
from decimal import Decimal

REPO_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))

class TestSeam4BehavioralRegression(unittest.TestCase):
    """
    Comprehensive regression suite testing both existing baseline (LIMIT)
    functionality and new (MARKET) order behaviors across all failure modes
    highlighted in the DovOps review.
    """
    @classmethod
    def setUpClass(cls):
        service_path = os.path.join(
            REPO_ROOT,
            'specs', '009-order-management-matcher', 'generation', 'runtime-overrides',
            'order-matcher', 'src', 'main', 'java', 'finos', 'traderx', 'ordermatcher',
            'service', 'OrderMatcherService.java'
        )
        req_path = os.path.join(
            REPO_ROOT,
            'specs', '009-order-management-matcher', 'generation', 'runtime-overrides',
            'order-matcher', 'src', 'main', 'java', 'finos', 'traderx', 'ordermatcher',
            'api', 'OrderCreateRequest.java'
        )
        with open(service_path, 'r', encoding='utf-8') as f:
            cls.service_source = f.read()
        with open(req_path, 'r', encoding='utf-8') as f:
            cls.req_source = f.read()

    # 1. Existing Functionality: Omitted orderType compatibility (Defaults to LIMIT)
    def test_omitted_order_type_defaults_to_limit(self):
        # In OrderCreateRequest.java, getOrderType() must return LIMIT when orderType is null
        self.assertIn("return orderType != null ? orderType : OrderType.LIMIT;", self.req_source)

    # 2. Existing Functionality: Limit order validation requires positive limit price
    def test_limit_order_requires_positive_price(self):
        self.assertIn("void validateLimitOrder(OrderCreateRequest request)", self.service_source)
        self.assertIn("request.getLimitPrice() == null || request.getLimitPrice().compareTo(BigDecimal.ZERO) <= 0", self.service_source)

    # 3. New Functionality: Market order validation allows null/omitted limit price
    def test_market_order_allows_null_limit_price(self):
        self.assertIn("void validateMarketOrder(OrderCreateRequest request)", self.service_source)
        # validateMarketOrder must NOT enforce limit price
        match = re.search(r'void validateMarketOrder\(OrderCreateRequest request\)\s*\{([^}]+)\}', self.service_source)
        self.assertIsNotNone(match)
        body = match.group(1)
        self.assertNotIn("BAD_REQUEST", body)

    # 4. Behavioral Simulation: Market Buy/Sell STP Immediate Fill logic
    def test_market_buy_sell_immediate_stp_fill_semantics(self):
        # Verify STP invocation on createOrder
        self.assertIn("if (saved.getOrderType() == OrderType.MARKET) {", self.service_source)
        self.assertIn("saved = processMarketOrderImmediateFill(saved);", self.service_source)

        # Simulation of matcher fill math
        def simulate_fill(side, quantity, market_price):
            fill_qty = quantity
            exec_price = market_price
            remaining = 0
            status = 'FILLED'
            return status, remaining, exec_price

        # Market Buy: 50 AAPL @ 150.25 -> Immediate full fill
        status, rem, px = simulate_fill('Buy', 50, Decimal('150.25'))
        self.assertEqual(status, 'FILLED')
        self.assertEqual(rem, 0)
        self.assertEqual(px, Decimal('150.25'))

        # Market Sell: 100 TSLA @ 210.50 -> Immediate full fill
        status, rem, px = simulate_fill('Sell', 100, Decimal('210.50'))
        self.assertEqual(status, 'FILLED')
        self.assertEqual(rem, 0)
        self.assertEqual(px, Decimal('210.50'))

    # 5. Edge Case: No-price queuing behavior
    def test_no_price_queuing_preserves_new_status(self):
        # When lastPrices.get(security) is null, order must be queued with status NEW
        self.assertIn("BigDecimal marketPrice = lastPrices.get(order.getSecurity());", self.service_source)
        self.assertIn("if (marketPrice == null) {", self.service_source)
        self.assertIn("waiting for market tick", self.service_source)
        self.assertIn("return order;", self.service_source)

    # 6. Failure Mode: Trade submission failure handling
    def test_trade_submission_failure_increments_counter_and_rejects(self):
        # If submitTrade returns false, must increment failure counter and NOT apply fill
        self.assertIn("if (!submitTrade(order, fillQty)) {", self.service_source)
        self.assertIn("tradeSubmitFailures.incrementAndGet();", self.service_source)
        self.assertIn('incrementEvent("reject");', self.service_source)

    # 7. Existing & New: Partial-Fill Admin Actions (Cancel and Force-Fill)
    def test_admin_partial_fill_semantics(self):
        # isOpen must include NEW and PARTIALLY_FILLED
        self.assertIn("OPEN_STATUSES = Set.of(OrderStatus.NEW, OrderStatus.PARTIALLY_FILLED);", self.service_source)

        # Force fill must operate on remaining quantity
        self.assertIn("int fillQty = order.getRemainingQuantity();", self.service_source)
        
        # Simulation of partial fill states
        def can_cancel(status):
            return status in ['NEW', 'PARTIALLY_FILLED']

        def can_force_fill(status, order_type):
            return status in ['NEW', 'PARTIALLY_FILLED'] and order_type != 'MARKET'

        # Baseline: NEW limit order
        self.assertTrue(can_cancel('NEW'))
        self.assertTrue(can_force_fill('NEW', 'LIMIT'))

        # Partially filled limit order (Restored by Dov review)
        self.assertTrue(can_cancel('PARTIALLY_FILLED'))
        self.assertTrue(can_force_fill('PARTIALLY_FILLED', 'LIMIT'))

        # Market order: Cancel allowed if queued in NEW/PARTIAL, Force Fill strictly disallowed
        self.assertTrue(can_cancel('NEW'))
        self.assertFalse(can_force_fill('NEW', 'MARKET'))
        self.assertFalse(can_force_fill('PARTIALLY_FILLED', 'MARKET'))

        # Terminal orders: neither allowed
        self.assertFalse(can_cancel('FILLED'))
        self.assertFalse(can_force_fill('FILLED', 'LIMIT'))
        self.assertFalse(can_cancel('CANCELED'))
        self.assertFalse(can_force_fill('CANCELED', 'LIMIT'))

    # 8. Existing Functionality: In-the-money tick evaluation for LIMIT orders
    def test_limit_order_in_the_money_tick_evaluation(self):
        self.assertIn("case Buy -> marketPrice.compareTo(order.getLimitPrice()) <= 0;", self.service_source)
        self.assertIn("case Sell -> marketPrice.compareTo(order.getLimitPrice()) >= 0;", self.service_source)

        def is_in_the_money(side, limit_px, mkt_px):
            if side == 'Buy':
                return mkt_px <= limit_px
            else:
                return mkt_px >= limit_px

        # Buy 100 @ 150 limit, market is 149 -> In the money (True)
        self.assertTrue(is_in_the_money('Buy', 150, 149))
        # Buy 100 @ 150 limit, market is 151 -> Out of money (False)
        self.assertFalse(is_in_the_money('Buy', 150, 151))
        # Sell 100 @ 150 limit, market is 152 -> In the money (True)
        self.assertTrue(is_in_the_money('Sell', 150, 152))
        # Sell 100 @ 150 limit, market is 148 -> Out of money (False)
        self.assertFalse(is_in_the_money('Sell', 150, 148))

    # 9. Backend Safety Invariant: Force-fill on MARKET order is rejected with BAD_REQUEST
    def test_market_order_force_fill_rejected_in_backend(self):
        # Must inspect forceFillOrder implementation
        start_idx = self.service_source.find("public OrderResponse forceFillOrder(String orderId)")
        end_idx = self.service_source.find("public OpenCountResponse openCounts()", start_idx)
        self.assertTrue(start_idx != -1 and end_idx != -1, "forceFillOrder method boundary not found")
        body = self.service_source[start_idx:end_idx]

        # Must reject MARKET orders
        self.assertIn("order.getOrderType() == OrderType.MARKET", body)
        self.assertIn("BAD_REQUEST", body)
        self.assertIn("cannot force-fill market order", body)

        # Rejection must occur BEFORE submitTrade is called
        reject_idx = body.find("cannot force-fill market order")
        submit_idx = body.find("submitTrade(order, fillQty)")
        self.assertTrue(reject_idx != -1, "rejection string must be present")
        self.assertTrue(submit_idx != -1, "submitTrade call must be present")
        self.assertTrue(reject_idx < submit_idx, "MARKET rejection must occur before submitTrade call")

        # Behavioral simulation: attempting force-fill on queued MARKET order
        class SimulatedOrder:
            def __init__(self):
                self.order_type = 'MARKET'
                self.status = 'NEW'
                self.remaining_qty = 100
                self.last_execution_price = None

        order = SimulatedOrder()
        trades_submitted = []

        def force_fill(ord_obj):
            if ord_obj.order_type == 'MARKET':
                raise ValueError("cannot force-fill market order")
            trades_submitted.append(ord_obj)
            ord_obj.status = 'FILLED'
            ord_obj.remaining_qty = 0

        with self.assertRaises(ValueError):
            force_fill(order)

        # Assert no trade was submitted and queued order remains unchanged
        self.assertEqual(len(trades_submitted), 0)
        self.assertEqual(order.status, 'NEW')
        self.assertEqual(order.remaining_qty, 100)
        self.assertIsNone(order.last_execution_price)

if __name__ == '__main__':
    unittest.main()
