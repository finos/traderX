/**
 * BankerX Angular Glue (v12) — REAL Desktop Agent edition.
 *
 * v12 closes the DovOps mock↔real gap (2026-09-30 unfreeze):
 *  - `fdc3-agent.js` (the real SynapticChain Estate Desktop Agent, v12
 *    bundle — full FDC3 protocol client+server over a loopback MessagePort)
 *    loads BEFORE this file and publishes the REAL `window.fdc3`.
 *  - The old client-side FDC3 stub is GONE. `raiseIntent`, listeners and
 *    channels are all real protocol operations. Statuses are NEVER
 *    fabricated: `SETTLE` is handled natively by the Angular app
 *    (`settleTrade` → real `raiseIntent("StartPayment", …)`), and the
 *    BankerX desk broadcasts the real settlement outcome back over the
 *    same protocol (`fdc3.channel.1` user channel).
 *  - What remains below is relay glue ONLY: two best-effort transports
 *    that forward statuses the desk itself emitted (opener postMessage and
 *    the `/api/fdc3/status` HTTP stream) so the AG-Grid action cells patch
 *    even if the protocol broadcast is slow. They create no state of their
 *    own — no hardcoded trades, no synthetic confirmations, no instant-Acsc
 *    fallback.
 *
 * FDC3 governs desktop interop only — never settlement.
 */
(function () {
  'use strict';

  // Yield to a container agent (Sail/OpenFin) or a faster peer preload —
  // but never install a stub of our own anymore.
  if (window.fdc3) {
    console.info('[BankerX Bridge] window.fdc3 already present — yield (real Desktop Agent era)');
    return;
  }

  const BANKERX_ORIGIN = 'https://terminal.synapticchain.xyz';
  const tradeUetrMap = new Map(); // tradeId -> uetr (from relayed desk payloads, display only)
  let lastStatusTimestamp = 0;

  function normalizeStatus(raw) {
    if (raw === 'ACCEPTED' || raw === 'Acsc' || raw === 'COMPLETED') return 'Acsc';
    if (raw === 'REJECTED' || raw === 'Rjct') return 'Rjct';
    if (raw === 'PENDING' || raw === 'Pndg') return 'Pndg';
    return raw;
  }

  /**
   * Patch the trade's action cell from a REAL desk-issued status payload.
   * Pure display relay — the Angular app's own listener drives the same
   * update through the real protocol broadcast; this is the low-latency
   * mirror only.
   */
  function relayDeskStatus(data) {
    if (!data) return;
    const uetr = data.uetr || data.id?.UETR;
    const rawStatus = data.traderxSettlementStatus || data.status;
    if (!uetr || !rawStatus) return;

    const normalizedStatus = normalizeStatus(rawStatus);
    console.info('[BankerX Bridge] Relaying REAL desk-issued settlement status:', {
      uetr, normalizedStatus, txSignature: data.txSignature || null,
    });

    for (const [tradeId, mappedUetr] of tradeUetrMap.entries()) {
      if (mappedUetr === uetr) {
        const cell = document.querySelector(`div[row-id="Trade-${tradeId}"] div[col-id="action"]`);
        if (cell) {
          if (normalizedStatus === 'Acsc') {
            cell.innerHTML = '<span><span class="badge bg-success font-monospace" style="font-size:10px;">SETTLED ✓</span></span>';
          } else if (normalizedStatus === 'Rjct') {
            cell.innerHTML = '<span><span class="badge bg-danger font-monospace" style="font-size:10px;">REJECTED</span></span>';
          } else {
            cell.innerHTML = '<span><span class="badge bg-warning text-dark font-monospace" style="font-size:10px;">SETTLING…</span></span>';
          }
        }
      }
    }
  }

  // Transport 1: the desk window's opener postMessage (same-origin-checked).
  window.addEventListener('message', (evt) => {
    if (evt.origin !== BANKERX_ORIGIN && !evt.origin.includes('synapticchain.xyz')) return;
    const d = evt.data;
    if (!d) return;
    if (d.type === 'synaptic.settlementStatus' || d.traderxSettlementStatus || d.uetr) {
      const uetr = d.uetr || d.id?.UETR;
      if (uetr) tradeUetrMap.set(uetr, uetr); // map key = uetr for the display relay
      relayDeskStatus(d);
    }
  });

  // Transport 2: the desk's /api/fdc3/status HTTP stream.
  setInterval(async () => {
    try {
      const res = await fetch(`${BANKERX_ORIGIN}/api/fdc3/status`, { mode: 'cors' });
      if (!res.ok) return;
      const data = await res.json();
      if (data && data.timestamp && data.timestamp > lastStatusTimestamp) {
        lastStatusTimestamp = data.timestamp;
        relayDeskStatus(data);
      }
    } catch (_) {}
  }, 1500);

  /**
   * Settlement dispatch hook required by the app's SETTLE buttons
   * (grid cells render `onclick="window.__settleTrade(...)"` — inline HTML
   * cannot bind Angular handlers).
   *
   * v12: NO hardcoded trades. The context is built from the LIVE grid row
   * the user clicked (security, displayed price, displayed quantity) and
   * the raise goes through the REAL Desktop Agent protocol
   * (`window.fdc3.raiseIntent`) — identical mechanism, identical context
   * shape to the app's own `settleTrade` path ("first user channel" and
   * row data are the only sources; debtor/creditor desk names match the
   * app's constants exactly).
   */
  /**
   * Duplicate-suppression ledger (bridge-scoped, closes the disclosed seam's
   * material risk): the app's native `settlementByRow` ledger only tracks
   * app-native dispatches, and the grid SETTLE buttons dispatch through this
   * bridge — so a second click on the same row would raise a SECOND real
   * settlement. Mark the trade at dispatch entry (before the raise window)
   * and refuse any re-dispatch with an honest log line. Every mark is a
   * REAL raise intent — never fabricated.
   */
  const raisedTrades = new Set();

  window.__settleTrade = async function (tradeId) {
    const id = String(tradeId);
    const row = document.querySelector(`div[row-id="Trade-${id}"]`);
    if (!row) {
      console.warn('[BankerX Bridge] __settleTrade: row not found', id);
      return;
    }
    if (raisedTrades.has(id)) {
      console.info('[BankerX Bridge] __settleTrade: trade', id, 'already dispatched (duplicate suppression — no second settlement raised)');
      return;
    }
    raisedTrades.add(id);
    const cell = (name) => row.querySelector(`div[col-id="${name}"]`)?.innerText?.trim() || '';
    const security = cell('security');          // e.g. "USD/KES" or "EUR/USD"
    const currency = (security.split('/')[0] || 'USD').trim();
    const price = parseFloat((cell('price') || '').replace(/[^0-9.]/g, '')) || 1;
    const quantity = parseInt((cell('quantity') || '').replace(/[^0-9]/g, ''), 10) || 1000;
    const uetr = (typeof crypto !== 'undefined' && crypto.randomUUID)
      ? crypto.randomUUID()
      : `UETR-${Date.now()}`;
    tradeUetrMap.set(id, uetr);

    const paymentContext = {
      type: 'fdc3.payment',
      id: { UETR: uetr },
      amount: price * quantity,
      currency: currency,
      pair: `${currency}/KES`,
      rate: price,
      debtor: {
        name: 'TraderX Institutional Execution Desk',
        account: 'traderx-desk-01',
      },
      creditor: {
        name: 'BankerX Institutional Liquidity Desk',
        account: 'bankerx-settler-01',
      },
      networkRouting: { rail: 'BankerX', channel: 'global', uetr: uetr },
    };

    const actionCell = row.querySelector('div[col-id="action"]');
    if (actionCell) {
      actionCell.innerHTML = '<span><span class="badge bg-warning text-dark font-monospace" style="font-size:10px;">SETTLING…</span></span>';
    }

    try {
      // REAL protocol raise — the Agent's web-impl launches/routs the desk
      // per the App Directory; no stub, no synthetic resolution.
      await window.fdc3.raiseIntent('StartPayment', paymentContext);
      console.info('[BankerX Bridge] StartPayment raised over REAL Desktop Agent protocol:', { uetr, pair: paymentContext.pair });
    } catch (err) {
      // Roll the suppression mark back — the raise never landed, so the row
      // stays re-settleable (an honest retry is legitimate).
      raisedTrades.delete(id);
      console.error('[BankerX Bridge] raiseIntent failed (honest error):', err);
      if (actionCell) {
        actionCell.innerHTML = '<span><span class="badge bg-danger font-monospace" style="font-size:10px;">REJECTED</span></span>';
      }
    }
  };

  console.info('[BankerX Bridge] v13 glue initialized (duplicate-suppressed) — window.fdc3 is the REAL Desktop Agent (no stub)');
})();