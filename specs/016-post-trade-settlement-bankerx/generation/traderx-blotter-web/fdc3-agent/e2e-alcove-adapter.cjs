// E2E v10: traderX → BankerX through the REAL FINOS FDC3 Desktop Agent path,
// PLUS the Alcove ADR-555 adapter path with the seam-closing fixes:
//   S2  lane routing — a directory-miss raise is screened by the enclave and
//       the rendezvous lane ROUTES it to a real partition desk (lanes
//       128–255 → bankerx-clearing-desk-eu); the EU desk window is launched
//       through the normal FDC3 open path and executes the settlement there.
//   S3  desk-side attestation — the delivered context carries the enclave's
//       WOTS+ proof; the desk re-derives the leaf root via the enclave's
//       verify_preflight tool BEFORE settling.
//   S4  canonical fees — the guardian derives the 0.50% levy server-side.
//   Honest rejection — a raise whose debtor is a sanctioned entity is
//       screened, REJECTED by the enclave, and the caller receives
//       RejectedByEnclave:SANCTIONS_POLICY_VIOLATION.
//
// Gates (13):
//   agentReady   — estate DA booted
//   wcpBound     — BankerX StartPayment listener bound via getAgent()
//   raiseOk      — primary raise resolved in the blotter DOM log
//   acsc         — primary trade ACSC in blotter
//   inboundCount === 2 — desks received exactly 2 StartPayment raises
//   dupCount === 0     — no duplicate dispatches
//   screenPassed — __ALCOVE_SCREEN shows ADR-555 pre-flight PASS with lane
//   routedDeskCorrect — delivered desk == partition lookup of the lane
//   secondAcsc   — the directory-miss trade also reached ACSC (in eu desk)
//   attestationVerified — routed desk logged desk-side WOTS+ re-derivation
//   rejectionHonest — sanctioned-debtor raise rejected with RejectedByEnclave
//   receiptModal — pacs.002 receipt modal open on ACSC
//   intentModalSeen — intent modal surfaced on the real flow
const { chromium } = require('playwright-core');

const TRADERX = 'https://traderx.synapticchain.xyz/';

// Partition table mirror (appd.ts customProps.alcovePartitions) — used to
// independently verify the agent's routing decision.
function partitionDesk(lane) {
  if (lane === null || lane === undefined) return null;
  if (lane >= 0 && lane <= 127) return 'bankerx-clearing-desk';
  if (lane >= 128 && lane <= 255) return 'bankerx-clearing-desk-eu';
  return null;
}

(async () => {
  const browser = await chromium.launch({
    executablePath: '/opt/google/chrome/chrome',
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-popup-blocking'],
  });
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 1000 } });
  const page = await ctx.newPage();

  const logs = { traderx: [], desk: [] };
  const tConsole = (lines, msg) => {
    const text = msg.text();
    if (/Cannot message|EstateDA|Alcove|FDC3|BankerX|SPEC-016|UETR/.test(text)) lines.push(text.slice(0, 300));
  };
  page.on('console', (m) => tConsole(logs.traderx, m));
  // Auto-attach console capture to EVERY popup (main desk + routed eu desk).
  ctx.on('page', (p) => {
    p.on('console', (m) => tConsole(logs.desk, m));
  });

  await page.goto(TRADERX + '?launcher=1', { waitUntil: 'domcontentloaded', timeout: 45000 });
  await page.waitForTimeout(3000);

  // 1. Launch BankerX through the desktop agent
  const [popup] = await Promise.all([
    ctx.waitForEvent('page', { timeout: 20000 }),
    page.click('#launchBtn'),
  ]);
  await popup.waitForLoadState('domcontentloaded', { timeout: 45000 });
  await popup.waitForTimeout(2500);

  // 2. Wait for the WCP-bound StartPayment listener
  let wcpBound = false;
  for (let i = 0; i < 20; i++) {
    wcpBound = logs.desk.some((l) => l.includes('listener registered via getAgent()'));
    if (wcpBound) break;
    await page.waitForTimeout(500);
  }

  // 3. Trade 1 → direct desk path
  await page.click('.exec-btn').catch(() => {});
  await page.waitForTimeout(1500);
  const settleBtn = page.locator("button:has-text('SETTLE (BANKERX)')").first();
  await settleBtn.waitFor({ state: 'visible', timeout: 15000 });
  await settleBtn.click();

  // 4. Wait for ACSC #1 in the blotter
  let acsc = false;
  let raiseOk = false;
  for (let i = 0; i < 60; i++) {
    const body = await page.evaluate(() => document.body.innerText);
    acsc = /ACSC/i.test(body);
    raiseOk = body.includes('fdc3.raiseIntent("StartPayment")');
    if (acsc && raiseOk) break;
    await page.waitForTimeout(1000);
  }

  // 5. Trade 2 → directory-miss path (geneva target NOT in the directory);
  //    the lane must ROUTE it to the eu partition desk (second window).
  const deskWindowsBefore = ctx.pages().length;
  await page.click('.exec-btn').catch(() => {});
  await page.waitForTimeout(1500);
  const enclaveBtn = page.locator("button:has-text('SETTLE (ENCLAVE)')").first();
  await enclaveBtn.waitFor({ state: 'visible', timeout: 15000 });
  await enclaveBtn.click();

  // 6. Wait for the second trade's ACSC (2 settled rows) + the routed window.
  //    attestVerifiedSeen is captured DURING the poll: a later raise (trade 3)
  //    re-shows the intent modal and resets #imAttest to "—", so the row must
  //    be observed live, not at the end.
  let secondAcsc = false;
  let screenPassed = null;
  let deskDelivered = null;
  let attestVerifiedSeen = false;
  const pollHistory = [];
  for (let i = 0; i < 90; i++) {
    const st = await page.evaluate(() => ({
      doneCount: document.querySelectorAll('.st-done').length,
      alcove: window.__ALCOVE_SCREEN || [],
      receiptOpen: !!document.querySelector('#receiptModal.open'),
      attestText: document.getElementById('imAttest')
        ? document.getElementById('imAttest').textContent : null,
    }));
    secondAcsc = st.doneCount >= 2;
    if (st.attestText && st.attestText.includes('VERIFIED')) attestVerifiedSeen = true;
    pollHistory.push({ i, doneCount: st.doneCount, attest: st.attestText });
    const passed = st.alcove.find((e) => e.stage === 'screen-passed');
    const delivered = st.alcove.find((e) => e.stage === 'desk-delivered');
    screenPassed = passed
      ? { lane: passed.lane, latencyMs: passed.latencyMs, desk: passed.desk, uetr: passed.uetr }
      : null;
    deskDelivered = delivered
      ? { desk: delivered.desk, instanceId: delivered.instanceId || null, uetr: delivered.uetr }
      : null;
    if (secondAcsc) break;
    await page.waitForTimeout(1000);
  }
  // Keep watching the row for up to 15s more (a late relay delivery may set
  // the VERIFIED row after the done-count flips).
  for (let i = 0; i < 15 && !attestVerifiedSeen; i++) {
    const st = await page.evaluate(() => ({
      attestText: document.getElementById('imAttest')
        ? document.getElementById('imAttest').textContent : null,
      doneCount: document.querySelectorAll('.st-done').length,
      alcove: window.__ALCOVE_SCREEN || [],
    }));
    if (st.attestText && st.attestText.includes('VERIFIED')) attestVerifiedSeen = true;
    pollHistory.push({ i: 'post', doneCount: st.doneCount, attest: st.attestText });
    if (st.attestText && st.attestText.includes('VERIFIED')) break;
    await page.waitForTimeout(1000);
  }
  const routedDeskCorrect =
    !!screenPassed && !!deskDelivered &&
    partitionDesk(screenPassed.lane) === deskDelivered.desk &&
    deskDelivered.desk === 'bankerx-clearing-desk-eu';

  // 7. Attestation verified desk-side: routed eu desk window console log AND
  //    the blotter's ATTESTATION row observed live showing VERIFIED.
  const attestationVerified =
    logs.desk.some((l) => l.includes('Alcove attestation verified desk-side')) &&
    attestVerifiedSeen;

  // 8. Receipt + intent modals + attestation row
  const receiptModal = await page.evaluate(
    () => !!document.querySelector('#receiptModal.open')
  );
  const intentModalSeen = await page.evaluate(
    () => document.getElementById('intentModal')?.dataset.seen === '1'
  );
  const attestRow = await page.evaluate(() =>
    document.getElementById('imAttest')?.textContent ?? '');

  // 9. Trade 3 → honest rejection: sanctioned debtor screened by the enclave
  const rejectionHonest = await page.evaluate(async () => {
    const agent = window.SynapticFDC3Agent;
    if (!agent || typeof agent.raiseIntent !== 'function') return { ok: false, err: 'no-agent' };
    const ctx = {
      type: 'fdc3.payment',
      id: { UETR: crypto.randomUUID() },
      amount: 750000,
      currency: 'USD',
      pair: 'USD/KES',
      debtor: { name: 'IRAN-CBI-TEHRAN', account: '4cghWNxgU73yh1SuRK1juQzt8EaKtC8HWGq2yK4jLmeG' },
      creditor: { name: 'Institutional Liquidity Desk', account: 'BnuCTFWFLLXnSPv2Frs42royiTAYG87WP7p1zRLB4ksG' },
    };
    try {
      await agent.raiseIntent('StartPayment', ctx, 'bankerx-clearing-desk-geneva');
      return { ok: false, err: 'raise-resolved-but-should-have-rejected' };
    } catch (e) {
      const msg = String(e?.message ?? e);
      return {
        ok: /RejectedByEnclave/.test(msg) && /SANCTIONS_POLICY_VIOLATION/.test(msg),
        err: msg.slice(0, 200),
      };
    }
  });

  // 10. Counts
  const dupCount = logs.desk.filter((l) => l.includes('Duplicate StartPayment')).length;
  const inboundCount = logs.desk.filter((l) => l.includes('Inbound FDC3 StartPayment')).length;
  const agentReady = logs.traderx.some((l) => l.includes('Desktop agent ready'));
  const screenEvents = await page.evaluate(() => window.__ALCOVE_SCREEN || []);

  console.log('=== RESULT ===');
  console.log(JSON.stringify({
    agentReady, wcpBound, raiseOk, acsc, inboundCount, dupCount,
    screenPassed, routedDeskCorrect, deskDelivered, secondAcsc,
    attestationVerified, attestRow: attestRow + ' (final; live VERIFIED seen: ' + attestVerifiedSeen + ')',
    rejectionHonest, receiptModal, intentModalSeen,
    alcoveStages: screenEvents.map((e) => e.stage),
    pollHistory,
  }, null, 2));
  console.log('=== DESK LOG ===');
  logs.desk.forEach((l) => console.log('B:', l));

  await browser.close();
  const ok =
    agentReady && wcpBound && raiseOk && acsc &&
    inboundCount === 2 && dupCount === 0 &&
    !!screenPassed && routedDeskCorrect && !!deskDelivered &&
    secondAcsc && attestationVerified &&
    rejectionHonest.ok === true && receiptModal && intentModalSeen;
  process.exit(ok ? 0 : 1);
})().catch((e) => {
  console.error('E2E ERROR:', e.message);
  process.exit(2);
});