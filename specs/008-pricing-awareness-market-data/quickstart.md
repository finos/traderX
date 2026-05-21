# Quickstart: Pricing Awareness and Market Data Streaming

## 1) Generate State 008

```bash
bash pipeline/generate-state.sh 008-pricing-awareness-market-data
```

## 2) Start / Verify / Test / Stop

```bash
./scripts/start-state-008-pricing-awareness-market-data-generated.sh
./scripts/start-state-008-pricing-awareness-market-data-generated.sh --skip-build
./scripts/status-state-008-pricing-awareness-market-data-generated.sh
./scripts/test-state-008-pricing-awareness-market-data.sh
./scripts/test-state-008-pricing-awareness-market-data.sh --skip-messaging
./scripts/test-messaging-008-pricing-awareness-market-data.sh
./scripts/stop-state-008-pricing-awareness-market-data-generated.sh
```
