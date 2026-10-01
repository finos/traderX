// State 016 offline acceptance harness (pack E2E, headless).
// Drives: blotter (in-page Estate DA) → LAUNCH BANKERX → mock receiver popup
// (WCP getAgent) → execTrade → SETTLE (desk raise) → Acsc → SETTLED + receipt
// modal → duplicate suppression (FR-01607 guard + receiver duplicate replay) →
// honest rejection (invalid UETR → Rjct + schema reason).
// Usage: node acceptance-016.cjs <base-url> <run-label>
const path = require('path');
const { chromium } = require(path.join(__dirname, 'node_modules', 'playwright-core'));

const BASE = process.argv[2] || 'http://localhost:8095';
const LABEL = process.argv[3] || 'debug';
const EXE = process.env.CHROME_EXE || "/opt/google/chrome/chrome";

const blotterUrl = `${BASE}/generation/traderx-blotter-web/index.html?launcher=1&directory=${encodeURIComponent(`${BASE}/acceptance/appd.json`)}`;

const results = [];
const gate = (name, ok, why) => {
  results.push({ name, ok, why });
  console.log(`${ok ? 'PASS' : 'FAIL'} ${LABEL} ${name}${why ? ' — ' + why : ''}`);
};

(async () => {
  const browser = await chromium.launch({
    executablePath: EXE,
    headless: true,
    args: ['--no-sandbox', '--disable-dev-shm-usage', '--disable-popup-blocking', '--window-size=1600,1000'],
  });
  const ctx = await browser.newContext({ viewport: { width: 1600, height: 1000 } });
  const logs = []; // real console messages, tagged by page
  const attach = (page, tag) => {
    page.on('console', (m) => logs.push({ t: m.text(), tag }));
    page.on('pageerror', (e) => logs.push({ t: `PAGEERROR ${e.message}`, tag }));
  };

  const blotter = await ctx.newPage();
  attach(blotter, 'blotter');

  let receiver = null;
  ctx.once('page', (p) => { receiver = p; attach(p, 'receiver'); });

  const saw = (needle) => logs.some((l) => l.t.includes(needle));

  // The blotter logs to an in-page DOM log (not console) — read it.
  const blotterLog = async () =>
    (await blotter.evaluate(() =>
      Array.from(document.getElementById('log').children).map((d) => d.textContent)
    ).catch(() => [])) || [];
  const domSaw = async (needle) => (await blotterLog()).some((l) => l.includes(needle));
  const domMatch = async (re) => {
    for (const l of await blotterLog()) { const m = l.match(re); if (m) return m; }
    return null;
  };

  const waitFor = async (fn, ms) => {
    const t0 = Date.now();
    for (;;) {
      let v;
      try { v = await fn(); } catch { v = null; }
      if (v) return v;
      if (Date.now() - t0 > ms) return null;
      await new Promise((r) => setTimeout(r, 150));
    }
  };

  const finish = async (code) => {
    const fails = results.filter((r) => !r.ok);
    await browser.close().catch(() => {});
    console.log(`== ${LABEL}: ${results.length - fails.length}/${results.length}`);
    process.exit(fails.length ? 1 : code);
  };

  await blotter.goto(blotterUrl, { waitUntil: 'load' });

  // Gate 1: realFdc3 — blotter Estate DA ready (console).
  gate('realFdc3', !!(await waitFor(() => (saw('[EstateDA] Desktop agent ready') ? true : null), 20000)),
    '[EstateDA] Desktop agent ready');

  // Gate 2: deskOpen — agent opens the receiver through the directory record.
  await blotter.bringToFront();
  await blotter.click('#launchBtn');
  receiver = await waitFor(async () => {
    for (const p of ctx.pages()) if (p !== blotter && p.url().includes('mock-receiver') && !p.isClosed()) return p;
    return null;
  }, 15000);
  const openLogged = await domSaw('Desktop agent open("bankerx-clearing-desk") → instance');
  gate('deskOpen', !!receiver && openLogged,
    receiver ? (openLogged ? 'receiver popup + agent instance log' : 'receiver popup but no agent instance log') : 'no receiver popup');
  if (!receiver) return finish(1);

  // Gate 3: wcpConnected — receiver's getAgent() WCP client connects.
  const wcp = await waitFor(async () => {
    return !receiver.isClosed() && saw('[MockReceiver] WCP agent connected via getAgent()') ? true : null;
  }, 15000);
  gate('wcpConnected', !!wcp, 'receiver console: WCP agent connected via getAgent()');

  // Book a trade via the ticket.
  await blotter.bringToFront();
  await blotter.click('#btnBuy');
  await blotter.click('.exec-btn');
  const booked = await waitFor(async () => await domMatch(/\[BLOTTER\] Trade #(\d+) executed/), 8000);
  const uetr = await waitFor(async () => {
    const m = await domMatch(/\[UETR\] ([0-9a-f-]{36})/);
    return m ? m[1] : null;
  }, 8000);
  const tradeId = booked ? Number(booked[1]) : null;
  gate('tradeBooked', !!tradeId && !!uetr, `trade #${tradeId} · UETR ${uetr}`);
  if (!tradeId || !uetr) return finish(1);

  // Gate 4-6: raise StartPayment at the directory-declared desk.
  await blotter.evaluate((id) => window.settleTrade(id).catch((e) =>
    console.warn('settleTrade harness error:', String(e))), tradeId);

  const verdictGood = await waitFor(async () => {
    if (receiver.isClosed()) return null;
    const html = await receiver.evaluate(() => document.getElementById('paymentList').innerHTML).catch(() => '');
    return html.includes(uetr) && html.includes('badge good') ? true : null;
  }, 25000);
  gate('intentReceived', !!verdictGood, `receiver processed fdc3.payment · UETR ${uetr.slice(0, 8)}…`);

  const rowSettled = await waitFor(async () => {
    return await blotter.evaluate((id) => {
      const tr = document.getElementById(`tr-${id}`);
      return tr && tr.innerHTML.includes('ACSC') ? true : null;
    }, tradeId).catch(() => null);
  }, 10000);
  const acscLogged = await domSaw('synaptic.settlementStatus Acsc received');
  gate('acsc', !!verdictGood && !!rowSettled && acscLogged,
    `row ${tradeId} ACSC ✓ + Acsc status log=${acscLogged}`);

  const receipt = await waitFor(async () => {
    return await blotter.evaluate(() => {
      const m = document.getElementById('receiptModal');
      return m && m.classList.contains('open') ? true : null;
    }).catch(() => null);
  }, 8000);
  gate('receiptModal', !!receipt, 'receipt modal open on Acsc');

  // Gate 7a: FR-01607 guard — re-dispatch of a settled UETR refused.
  await blotter.evaluate(async (settledUetr) => {
    const orig = crypto.randomUUID.bind(crypto);
    crypto.randomUUID = () => settledUetr;
    try { window.execTrade(); } finally { crypto.randomUUID = orig; }
  }, uetr);
  await blotter.waitForTimeout(300);
  const tradeId2 = (() => {
    const re = /\[BLOTTER\] Trade #(\d+) executed/g; let last = null;
    for (const l of logs) { const m = (l.t || '').match(re); }
    return null;
  })();
  void tradeId2;
  const newTradeId = await waitFor(async () => {
    const ids = await blotter.evaluate(() =>
      Array.from(document.querySelectorAll('#blotterBody tr')).map((r) => r.id).filter((s) => s.startsWith('tr-')))
      .catch(() => []);
    const id = Math.max(...ids.map((s) => Number(s.slice(3))));
    return Number.isFinite(id) ? id : null;
  }, 5000);
  let guardRefused = false;
  if (newTradeId != null && Number.isFinite(newTradeId)) {
    await blotter.evaluate((id) => window.settleTrade(id).catch(() => {}), newTradeId);
    guardRefused = await domSaw('FR-01607] Duplicate dispatch blocked');
  }
  gate('dupSuppressed', !!guardRefused, `FR-01607 guard refused re-dispatch of ${uetr.slice(0, 8)}… (row ${newTradeId})`);

  // Gate 7b: receiver-side duplicate replay (API-level raise of the same UETR).
  let receiverDup = false;
  if (!receiver.isClosed()) {
    const raised = await blotter.evaluate(async (settledUetr) => {
      const agent = window.SynapticFDC3Agent;
      if (!agent) return 'no-agent';
      try {
        await agent.ready;
        await agent.raiseIntent('StartPayment', {
          type: 'fdc3.payment',
          id: { UETR: settledUetr },
          amount: 2500000, currency: 'USD', pair: 'USD/KES', rate: 129.42,
          debtor: { name: 'TraderX Institutional Execution Desk', account: '4cghWNxgU73yh1SuRK1juQzt8EaKtC8HWGq2yK4jLmeG' },
          creditor: { name: 'BankerX Institutional Liquidity Desk', account: 'BnuCTFWFLLXnSPv2Frs42royiTAYG87WP7p1zRLB4ksG' },
          networkRouting: { rail: 'Trilateral Powerhouse', channel: 'global', uetr: settledUetr },
        }, 'bankerx-clearing-desk');
        return 'raised';
      } catch (e) { return 'raise-failed: ' + String((e && e.message) || e); }
    }, uetr);
    console.log(`   (receiver-side duplicate re-raise: ${raised})`);
    receiverDup = await waitFor(async () => {
      if (receiver.isClosed()) return null;
      const html = await receiver.evaluate(() => document.getElementById('paymentList').innerHTML).catch(() => '');
      return html.includes('DUPLICATE — first outcome replayed') ? true : null;
    }, 15000);
  }
  gate('receiverDupReplay', !!receiverDup, 'receiver DUPLICATE — first outcome replayed');

  // Gate 8: rejectHonest — invalid context through the real agent raise.
  const rejUetr = 'not-a-uuid';
  const rejOk = await blotter.evaluate(async (x) => {
    const agent = window.SynapticFDC3Agent;
    if (!agent) return 'no-agent';
    try {
      await agent.ready;
      await agent.raiseIntent('StartPayment', {
        type: 'fdc3.payment',
        id: { UETR: x.badUetr },
        amount: 1000, currency: 'USD', pair: 'USD/KES', rate: 129.4,
        debtor: { name: 'TraderX Institutional Execution Desk', account: 'x' },
        creditor: { name: 'BankerX Institutional Liquidity Desk', account: 'y' },
        networkRouting: { rail: 'Trilateral Powerhouse', channel: 'global', uetr: x.badUetr },
      }, x.target);
      return 'raised';
    } catch (e) { return 'raise-failed: ' + String((e && e.message) || e); }
  }, { target: 'bankerx-clearing-desk', badUetr: rejUetr });
  const rejVerdict = await waitFor(async () => {
    if (receiver.isClosed()) return null;
    const html = await receiver.evaluate(() => document.getElementById('paymentList').innerHTML).catch(() => '');
    return html.includes(rejUetr) && html.includes('badge bad') ? true : null;
  }, 25000);
  const rejReason = !!rejVerdict && (await receiver.evaluate(() => document.getElementById('paymentList').innerHTML).catch(() => ''))
    .includes('uetr_not_rfc4122_uuidv4');
  gate('rejectHonest', !!rejVerdict && rejReason && rejOk === 'raised',
    `receiver Rjct · ${rejOk} · schema reason present=${rejReason}`);

  // On failure, dump page console evidence
  if (results.some((r) => !r.ok)) {
    console.log('--- console evidence ---');
    logs.filter((l) => /EstateDA|MockReceiver|WCP|getAgent|Alcove|PAGEERROR/.test(l.t))
      .slice(0, 40).forEach((l) => console.log(' *', l.t.slice(0, 220)));
  }
  return finish(0);
})().catch((e) => { console.error('HARNESS CRASH', (e && e.stack) || e); process.exit(9); });