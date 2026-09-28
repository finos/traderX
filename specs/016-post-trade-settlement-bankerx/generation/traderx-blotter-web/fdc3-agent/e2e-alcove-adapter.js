// E2E v7: traderX → BankerX through the REAL FINOS FDC3 Desktop Agent path,
//
// E2E harness for the Alcove ADR-555 adapter path (10 gates). Run with
// playwright-core + system Chrome: node e2e-alcove-adapter.js (exit 0 = all
// gates green). Proven x2 on fdc3-agent.js v9 (md5 7cf88907…) 2026-09-29.
// PLUS the Alcove ADR-555 adapter path: an intent targeted at a desk that is
// NOT in the App Directory (directory miss) must still land on the BankerX
// desk through the enclave screen (sanctions bloom + solvency + 256-lane
// rendezvous) — and the intent + receipt modals must surface on the real
// flow states.
//
// Gates (10):
//   agentReady   — estate DA booted
//   wcpBound     — BankerX StartPayment listener bound via getAgent()
//   raiseOk      — primary raise resolved in the blotter DOM log
//   acsc         — primary trade ACSC in blotter
//   inboundCount === 2 — desk received exactly 2 StartPayment raises (1 direct + 1 adapter)
//   dupCount === 0     — no duplicate dispatches
//   screenPassed — window.__ALCOVE_SCREEN shows ADR-555 pre-flight PASS with lane + desk
//   deskDelivered— __ALCOVE_SCREEN shows desk-delivered to bankerx-clearing-desk
//   secondAcsc   — the directory-miss trade also reached ACSC in the blotter
//   receiptModal — pacs.002 receipt modal open on ACSC
const { chromium } = require('playwright-core');

const TRADERX = 'https://traderx.synapticchain.xyz/';

(async () => {
  const browser = await chromium.launch({
    executablePath: '/opt/google/chrome/chrome',
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-popup-blocking'],
  });
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 1000 } });
  const page = await ctx.newPage();

  const logs = { traderx: [], bankerx: [] };
  const tConsole = (lines, msg) => {
    const text = msg.text();
    if (/Cannot message|EstateDA|Alcove|FDC3|BankerX|SPEC-016|UETR/.test(text)) lines.push(text.slice(0, 300));
  };
  page.on('console', (m) => tConsole(logs.traderx, m));

  await page.goto(TRADERX + '?launcher=1', { waitUntil: 'domcontentloaded', timeout: 45000 });
  await page.waitForTimeout(3000);

  // 1. Launch BankerX through the desktop agent
  const [popup] = await Promise.all([
    ctx.waitForEvent('page', { timeout: 20000 }),
    page.click('#launchBtn'),
  ]);
  popup.on('console', (m) => tConsole(logs.bankerx, m));
  await popup.waitForLoadState('domcontentloaded', { timeout: 45000 });
  await popup.waitForTimeout(2500);

  // 2. Wait for the WCP-bound StartPayment listener
  let wcpBound = false;
  for (let i = 0; i < 20; i++) {
    wcpBound = logs.bankerx.some((l) => l.includes('listener registered via getAgent()'));
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

  // 5. Trade 2 → directory-miss path (target not in App Directory)
  await page.click('.exec-btn').catch(() => {});
  await page.waitForTimeout(1500);
  const enclaveBtn = page.locator("button:has-text('SETTLE (ENCLAVE)')").first();
  await enclaveBtn.waitFor({ state: 'visible', timeout: 15000 });
  await enclaveBtn.click();

  // 6. Wait for the second trade's ACSC (2 settled rows)
  let secondAcsc = false;
  let screenPassed = null;
  let deskDelivered = null;
  for (let i = 0; i < 75; i++) {
    const st = await page.evaluate(() => ({
      doneCount: document.querySelectorAll('.st-done').length,
      alcove: window.__ALCOVE_SCREEN || [],
      receiptOpen: !!document.querySelector('#receiptModal.open'),
      intentText: document.querySelector('#intentModal')?.classList.contains('open')
        ? document.getElementById('imState').textContent : null,
    }));
    secondAcsc = st.doneCount >= 2;
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

  // 7. Receipt + intent modals
  const receiptModal = await page.evaluate(
    () => !!document.querySelector('#receiptModal.open')
  );
  const intentModalSeen = await page.evaluate(
    () => document.getElementById('intentModal')?.dataset.seen === '1'
  );

  // 8. Counts
  const dupCount = logs.bankerx.filter((l) => l.includes('Duplicate StartPayment')).length;
  const inboundCount = logs.bankerx.filter((l) => l.includes('Inbound FDC3 StartPayment')).length;
  const agentReady = logs.traderx.some((l) => l.includes('Desktop agent ready'));
  const screenEvents = await page.evaluate(() => window.__ALCOVE_SCREEN || []);

  console.log('=== RESULT ===');
  console.log(JSON.stringify({
    agentReady, wcpBound, raiseOk, acsc, inboundCount, dupCount,
    screenPassed, deskDelivered, secondAcsc, receiptModal, intentModalSeen,
    alcoveStages: screenEvents.map((e) => e.stage),
  }, null, 2));
  console.log('=== TRADERX LOG ===');
  logs.traderx.forEach((l) => console.log('T:', l));
  console.log('=== BANKERX LOG ===');
  logs.bankerx.forEach((l) => console.log('B:', l));

  await browser.close();
  const ok =
    agentReady && wcpBound && raiseOk && acsc &&
    inboundCount === 2 && dupCount === 0 &&
    !!screenPassed && !!deskDelivered &&
    deskDelivered.desk === 'bankerx-clearing-desk' &&
    secondAcsc && receiptModal && intentModalSeen;
  process.exit(ok ? 0 : 1);
})().catch((e) => {
  console.error('E2E ERROR:', e.message);
  process.exit(2);
});