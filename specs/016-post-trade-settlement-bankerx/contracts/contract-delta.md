# Contract Delta: FDC3 3.0 Payment Context & ISO 20022 Schema

**Feature Branch**: `016-post-trade-settlement-bankerx`  
**Standards Reference**: FINOS PR #2204, ISO 20022 pacs.008.001.08, pacs.002.001.10  

---

## 1. FDC3 Context Contract: `fdc3.paymentContext`

```typescript
export interface FDC3PaymentContext {
  type: "fdc3.paymentContext";
  id?: {
    UETR?: string; // RFC 4122 UUIDv4
    originalMsgId?: string;
  };
  amount: number; // Gross instructed amount
  currency: string; // ISO 4217 Currency (e.g. USD)
  pair: string; // FX Pair e.g. USD/KES
  rate: number; // Executed FX rate
  debtor: {
    name: string;
    account: string; // Account identifier or blockchain public key / ATA
    bic?: string;
    country?: string;
  };
  creditor: {
    name: string;
    account: string;
    bic?: string;
    country?: string;
  };
  networkRouting?: {
    rail: "Trilateral Powerhouse" | "Solana Token-2022" | "XRPL Altnet" | "SynapticChain SCBFT-L1";
    channel?: string;
    uetr?: string;
  };
}
```

---

## 2. Settlement Confirmation Receipt Contract: `pacs.002`

```typescript
export interface Pacs002Receipt {
  status: "Acsc"; // Accepted Settlement Completed
  statusCode: "G000";
  reason: string;
  clearingSystemRef: string;
  uetr: string; // SWIFT UETR
  txSignature?: string; // Solana Token-2022 transaction signature
  xrplTxHash?: string; // XRPL Altnet transaction hash
  slot?: number;
  timestamp: string; // ISO 8601 UTC
  pacs002Xml: string; // Full ISO 20022 pacs.002.001.10 XML document
}
```
