# NATS fixture and console verification

The isolated fixture passed 28 cases against pinned NATS 2.14.9: 16 explicit authentication/permission denials and 12 permitted deliveries over TLS and WSS. Console browser run `35d8fe0f-9387-44cd-9cb1-97180d315392` passed; the result table showed both transports and limitations. Authenticated remote evidence download returned the complete 28-case artifact. Private runtime retains the evidence bundle and screenshot; no credentials are included here.

51 unit tests passed, including fragmented broker-message parsing and oversized payload rejection. The fixture has an exclusive lock across CLI/console invocations and removes its owned broker/network and temporary credentials. Live C3 broker authentication, real browser identity and dynamic-account subject migration remain unimplemented. The current UI has ten executable scenarios.
