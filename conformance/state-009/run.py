#!/usr/bin/env python3
"""State-009 behavioral conformance, independent of implementation language."""
import argparse
import datetime
import json
import queue
import subprocess
import sys
import threading
import urllib.error
import urllib.request

LEGACY = {
    "orderId": "ord-013-0042", "accountId": 22214, "security": "IBM",
    "side": "Buy", "quantity": 20, "remainingQuantity": 10,
    "limitPrice": 100, "status": "PARTIALLY_FILLED",
    "createdAt": "2026-01-01T12:00:00Z", "updatedAt": "2026-01-01T12:01:00Z",
    "lastExecutionPrice": 99, "lastFillQuantity": 10,
}


class Driver:
    def __init__(self, command):
        self.process = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        text=True, bufsize=1)
        self.responses = queue.Queue()
        threading.Thread(target=self._read, daemon=True).start()

    def _read(self):
        for line in self.process.stdout:
            self.responses.put(line)
        self.responses.put(None)

    def call(self, operation, **arguments):
        self.process.stdin.write(json.dumps({"operation": operation, **arguments}) + "\n")
        self.process.stdin.flush()
        try:
            line = self.responses.get(timeout=120)
        except queue.Empty as error:
            raise RuntimeError(f"adapter timed out during {operation}") from error
        if line is None:
            raise RuntimeError(f"adapter exited during {operation}")
        response = json.loads(line)
        if "error" in response:
            raise RuntimeError(f"adapter {operation}: {response['error']}")
        return response

    def close(self):
        try:
            if self.process.poll() is None:
                self.call("cleanup")
        finally:
            self.process.stdin.close()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.terminate()
                self.process.wait(timeout=10)


def http(url, method="GET", body=None):
    request = urllib.request.Request(url, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, json.load(response)
    except urllib.error.HTTPError as error:
        return error.code, json.load(error)


def require(condition, message):
    if not condition:
        raise AssertionError(message)


def read_order(base, order_id):
    status, order = http(base + "/orders/" + order_id)
    require(status == 200, f"read {order_id}: expected HTTP 200, got {status}")
    return order


def persisted(order):
    # Compare contract fields, not unrelated response metadata or timestamp spelling.
    result = {field: order.get(field) for field in (*LEGACY, "orderType")}
    for field in ("createdAt", "updatedAt"):
        if result[field] is not None:
            result[field] = datetime.datetime.fromisoformat(result[field].replace("Z", "+00:00"))
    return result


def verify_preserved(base):
    order = read_order(base, LEGACY["orderId"])
    require(persisted(order) == persisted({**LEGACY, "orderType": "LIMIT"}),
            "upgrade changed legacy order fields or did not backfill LIMIT")


def scenario(driver, baseline):
    ready = driver.call("prepare", baseline=baseline, legacy_order=LEGACY if baseline == "legacy" else None)
    require(ready.get("contract_version") == 1, "adapter must implement state-009 contract version 1")
    endpoints = driver.call("start")
    base = endpoints["base_url"].rstrip("/")
    probe = endpoints["trade_probe_url"]
    if baseline == "legacy":
        verify_preserved(base)
    status, market = http(base + "/orders", "POST", {
        "accountId": 22214, "security": "IBM", "side": "Buy", "quantity": 10,
        "orderType": "MARKET",
    })
    require(status == 201, f"{baseline}: market creation expected HTTP 201, got {status}")
    require(market.get("orderType") == "MARKET" and market.get("limitPrice") is None,
            "market order must persist without a limit price")
    order_id = market["orderId"]
    before = read_order(base, order_id)
    require(before.get("status") == "NEW" and before.get("remainingQuantity") == 10,
            "without a price the market order must remain queued")
    probe_status, trades = http(probe)
    require(probe_status == 200 and trades["count"] == 0, "unexpected trade before force-fill")
    status, _ = http(base + "/orders/" + order_id + "/force-fill", "POST", {})
    require(status == 400, f"MARKET force-fill expected HTTP 400, got {status}")
    require(persisted(read_order(base, order_id)) == persisted(before), "rejected force-fill mutated the queued order")
    probe_status, trades = http(probe)
    require(probe_status == 200 and trades["count"] == 0, "rejected force-fill submitted a trade")
    endpoints = driver.call("restart")
    base = endpoints["base_url"].rstrip("/")
    require(persisted(read_order(base, order_id)) == persisted(before), "restart changed/lost the queued market order")
    if baseline == "legacy":
        verify_preserved(base)
    # Omitted orderType remains compatible after a repeated upgrade/startup.
    status, limit = http(base + "/orders", "POST", {
        "accountId": 22214, "security": "IBM", "side": "Buy", "quantity": 10,
        "limitPrice": 100,
    })
    require(status == 201 and limit.get("orderType") == "LIMIT", "omitted type must default to LIMIT")
    print(f"PASS state-009 {baseline}: preservation, market persistence, force-fill safety, restart, LIMIT default")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adapter", nargs=argparse.REMAINDER, required=True,
                        help="adapter command and arguments (executed without a shell)")
    args = parser.parse_args()
    if not args.adapter:
        parser.error("--adapter needs a command")
    driver = Driver(args.adapter)
    try:
        for baseline in ("fresh", "legacy"):
            scenario(driver, baseline)
    finally:
        driver.close()


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, RuntimeError, OSError, ValueError, KeyError) as error:
        print(f"FAIL state-009 conformance: {error}", file=sys.stderr)
        sys.exit(1)
