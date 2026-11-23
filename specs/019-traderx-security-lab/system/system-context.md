# State 019 system context

Learners interact with a local experiment console and identity-aware application through a TLS gateway. APIs and workers use scoped SQL and broker identities. A separately controlled collector records decisions and final effects. The assumed-compromised process must not own authoritative evidence or reset credentials.

See [architecture](architecture.md), [flows](flows.md) and [requirements](requirements.md). The deployed integrated topology remains a generation deliverable; current prototype checkpoints are explicitly narrower.
