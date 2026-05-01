# Quickstart: Messaging Layer Replacement with NATS

## 1) Generate State 006

```bash
bash pipeline/generate-state.sh 006-messaging-nats-replacement
```

## 2) Start / Verify / Test / Stop

```bash
./scripts/start-state-006-messaging-nats-replacement-generated.sh
./scripts/start-state-006-messaging-nats-replacement-generated.sh --skip-build
./scripts/status-state-006-messaging-nats-replacement-generated.sh
./scripts/test-state-006-messaging-nats-replacement.sh
./scripts/stop-state-006-messaging-nats-replacement-generated.sh
```
