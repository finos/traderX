/*
 * Spec 016 — receiver-side FDC3 client glue (acceptance/demo flow).
 *
 * When the mock receiver is opened by a FINOS FDC3 Desktop Agent (the
 * TraderX blotter's fdc3-agent.js), getAgent() performs the standard Web
 * Connection Protocol handshake (WCP1Hello → WCP3Handshake → MessageChannel)
 * against the opener and exposes a conformant DesktopAgent — the same desk-side
 * binding the BankerX terminal uses (PaymentPanel.tsx, lib/fdc3).
 *
 * The bundled agent is surfaced as a promise on window so the mock receiver's
 * module script can bind its StartPayment listener over the real protocol while
 * keeping its in-page stub fallback for direct (un-agented) opens.
 */
import { getAgent } from "@finos/fdc3-get-agent";

getAgent({ timeoutMs: 5000, intentResolver: false, channelSelector: false })
  .then((agent) => {
    if (typeof agent?.addIntentListener !== "function") {
      console.info("[MockReceiver] agent resolved without intent support — stub stays in use");
      return;
    }
    window.__MOCK_RECEIVER_AGENT = agent;
    window.dispatchEvent(new Event("mockreceiver:agent"));
    console.info("[MockReceiver] WCP agent connected via getAgent() — StartPayment deliverable");
  })
  .catch((e) => {
    console.info(
      "[MockReceiver] getAgent() found no desktop agent (expected on direct open) — stub stays in use:",
      e?.message ?? e,
    );
  });