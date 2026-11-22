#!/usr/bin/env python3
"""Disposable PostgreSQL/Java driver for the state-009 conformance protocol."""
import argparse
import http.server
import json
from pathlib import Path
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request


def command(*arguments, input=None):
    result = subprocess.run(arguments, input=input, text=True, capture_output=True, timeout=90)
    if result.returncode:
        raise RuntimeError(f"{arguments[0]} failed: {result.stderr[-2000:]}")
    return result.stdout.strip()


def quote(value):
    return "'" + str(value).replace("'", "''") + "'"


class TradeProbe(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_POST(self):
        self.server.submissions.append(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        self.respond({"accepted": True})

    def do_GET(self):
        self.respond({"count": len(self.server.submissions)})

    def respond(self, body):
        data = json.dumps(body).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


class ReferenceAdapter:
    def __init__(self, target):
        self.target = Path(target).resolve()
        jars = [p for p in (self.target / "order-matcher/build/libs").glob("*.jar")
                if not p.name.endswith("-plain.jar")]
        if len(jars) != 1:
            raise RuntimeError("Build order-matcher bootJar first; expected one executable JAR")
        self.jar = jars[0]
        self.container = None
        self.process = None
        self.probe = None
        self.workspace = None
        self.log = None

    def prepare(self, baseline, legacy_order):
        self.cleanup()
        self.workspace = tempfile.TemporaryDirectory(prefix="traderx-state009-conformance-")
        self.container = command("docker", "run", "--rm", "-d",
            "-e", "POSTGRES_PASSWORD=state009-conformance", "-e", "POSTGRES_DB=traderx",
            "-p", "127.0.0.1::5432", "postgres:16-alpine")
        for _ in range(60):
            try:
                self.sql("SELECT 1;")
                break
            except RuntimeError:
                time.sleep(0.5)
        else:
            raise RuntimeError("Disposable PostgreSQL did not become ready")
        self.port = command("docker", "port", self.container, "5432/tcp").rsplit(":", 1)[1]
        if baseline == "fresh":
            self.sql((Path(__file__).parent / "fresh-init.sql").read_text())
        elif baseline == "legacy":
            self.sql((Path(__file__).parent / "legacy-orderbook.sql").read_text())
            o = legacy_order
            fields = ("orderId", "accountId", "security", "side", "quantity", "remainingQuantity",
                      "limitPrice", "status", "createdAt", "updatedAt", "lastExecutionPrice", "lastFillQuantity")
            self.sql("INSERT INTO orderbook VALUES (" + ",".join(quote(o[f]) for f in fields) + ");")
        else:
            raise ValueError("Unknown baseline")
        self.probe = http.server.ThreadingHTTPServer(("127.0.0.1", 0), TradeProbe)
        self.probe.submissions = []
        threading.Thread(target=self.probe.serve_forever, daemon=True).start()
        return {"contract_version": 1}

    def sql(self, text):
        return command("docker", "exec", "-i", self.container, "psql", "-U", "postgres",
                       "-d", "traderx", "-v", "ON_ERROR_STOP=1", input=text)

    def start(self):
        if not self.container or not self.probe:
            raise RuntimeError("prepare must precede start")
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
        self.log = open(Path(self.workspace.name) / "matcher.log", "w+")
        self.base = f"http://127.0.0.1:{port}"
        self.probe_url = f"http://127.0.0.1:{self.probe.server_port}"
        self.process = subprocess.Popen([
            "java", "-jar", str(self.jar), f"--server.port={port}",
            f"--spring.datasource.url=jdbc:postgresql://127.0.0.1:{self.port}/traderx",
            "--spring.datasource.username=postgres", "--spring.datasource.password=state009-conformance",
            "--spring.jpa.properties.hibernate.jdbc.time_zone=UTC",
            "--order.matcher.publisher=noop", "--order.matcher.pricing-subscriber.enabled=false",
            "--order.matcher.seed-enabled=false", "--management.otlp.metrics.export.enabled=false",
            "--order.matcher.trade-service-url=" + self.probe_url + "/trade/",
        ], stdout=self.log, stderr=subprocess.STDOUT)
        for _ in range(120):
            if self.process.poll() is not None:
                break
            try:
                with urllib.request.urlopen(self.base + "/health", timeout=1) as response:
                    if response.status == 200:
                        return {"base_url": self.base, "trade_probe_url": self.probe_url}
            except (OSError, urllib.error.HTTPError):
                time.sleep(0.5)
        self.log.seek(0)
        raise RuntimeError("Matcher did not start: " + self.log.read()[-3000:])

    def stop(self):
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=10)
            self.process = None
        if self.log:
            self.log.close()
            self.log = None

    def restart(self):
        self.stop()
        return self.start()

    def cleanup(self):
        self.stop()
        if self.probe:
            self.probe.shutdown()
            self.probe.server_close()
            self.probe = None
        if self.container:
            command("docker", "rm", "-f", self.container)
            self.container = None
        if self.workspace:
            self.workspace.cleanup()
            self.workspace = None
        return {}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target-root", required=True, type=Path)
    args = parser.parse_args()
    adapter = ReferenceAdapter(args.target_root)
    try:
        for line in sys.stdin:
            try:
                request = json.loads(line)
                operation = request.pop("operation")
                if operation not in {"prepare", "start", "restart", "cleanup"}:
                    raise ValueError("Unknown adapter operation")
                response = getattr(adapter, operation)(**request)
            except Exception as error:
                response = {"error": str(error)}
            print(json.dumps(response), flush=True)
    finally:
        adapter.cleanup()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    main()
