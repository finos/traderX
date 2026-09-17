// Run through test-state-014-fdc3-playwright-smoke.sh with FDC3_TICKER_FILTER_TEST=1.
// Uses the real Sail DesktopAgent and generated TraderX application. Backend
// snapshots are deterministic fixtures; no window.fdc3 replacement is installed.
const { chromium } = require(process.env.TRADERX_PLAYWRIGHT_MODULE_DIR);
const assert = require('node:assert/strict');
const sailUrl = process.env.SAIL_URL || 'http://localhost:8090/html/';
const traderxUrl = process.argv[2] || 'http://localhost:8080/trade';
const origin = new URL(traderxUrl).origin;
const tickers = ['AAPL', 'MSFT'];
const rows = tickers.map((security, i) => ({
  id: String(i + 1), orderId: String(i + 1), accountId: 1, accountid: 1,
  security, quantity: 10, remainingQuantity: 10, averageCostBasis: 100,
  price: 100, limitPrice: 100, side: 'Buy', state: 'EXECUTED', status: 'NEW',
  created: '2026-09-17T08:00:00Z', updatedAt: '2026-09-17T08:00:00Z'
}));
const pauseUntil = async (test, description) => {
  for (let attempt = 0; attempt < 100; attempt++) {
    if (await test()) return;
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error(`Timed out: ${description}`);
};
const securities = async (host, kind) => host.locator(`app-${kind}-blotter .ag-center-cols-container .ag-cell[col-id="security"]`).allTextContents();
const expectRows = async (host, kind, expected) => pauseUntil(async () => {
  const actual = (await securities(host, kind)).map(s => s.trim()).sort();
  return JSON.stringify(actual) === JSON.stringify([...expected].sort());
}, `${kind} rows ${expected}`);

(async () => {
  const browser = await chromium.launch({ headless: true });
  try {
    const context = await browser.newContext();
    await context.route(`${origin}/**`, async route => {
      const pathname = new URL(route.request().url()).pathname;
      let data;
      if (pathname.startsWith('/account-service/')) data = [{ id: 1, displayName: 'Test account' }, { id: 2, displayName: 'Second account' }];
      else if (/\/position-service\/(trades|positions)/.test(pathname) || pathname === '/order-matcher/orders') data = rows;
      else if (pathname.startsWith('/reference-data/')) data = [];
      else return route.continue();
      await route.fulfill({ json: data });
    });
    const desktop = await context.newPage();
    await desktop.goto(sailUrl);
    await pauseUntil(() => Promise.resolve(desktop.frames().some(frame => frame.url().startsWith(traderxUrl))), 'TraderX embedded in Sail default layout');
    const app = desktop.frames().find(frame => frame.url().startsWith(traderxUrl));
    await app.getByText('FDC3 connected', { exact: false }).first().waitFor({ timeout: 60000 });
    await expectRows(app, 'trade', tickers);
    await expectRows(app, 'position', tickers);
    await app.locator('app-trade-blotter .ag-cell[col-id="security"]').filter({ hasText: 'AAPL' }).click();
    await expectRows(app, 'trade', tickers);
    await expectRows(app, 'position', tickers);
    await app.getByRole('button', { name: 'Orders', exact: true }).click();
    await expectRows(app, 'order', tickers);
    await app.getByLabel('Orders ticker filter', { exact: true }).selectOption('selected');
    await expectRows(app, 'order', ['AAPL']);
    // A real new window must recover retained channel context without opting in.
    const popupPromise = context.waitForEvent('page');
    await app.evaluate(url => window.open(url, '_blank'), traderxUrl);
    const popup = await popupPromise;
    await popup.getByText('FDC3 connected', { exact: false }).first().waitFor({ timeout: 60000 });
    await expectRows(popup, 'trade', tickers);
    assert.equal(await popup.getByLabel('Trades ticker filter', { exact: true }).inputValue(), 'all');
    await popup.getByLabel('Trades ticker filter', { exact: true }).selectOption('selected');
    await expectRows(popup, 'trade', ['AAPL']);
    await popup.getByLabel('Trades ticker filter', { exact: true }).selectOption('all');
    await popup.locator('app-trade-blotter .ag-cell[col-id="security"]').filter({ hasText: 'MSFT' }).click();
    await expectRows(app, 'order', ['MSFT']);
    await expectRows(popup, 'position', tickers);
    await app.getByRole('button', { name: 'Trades', exact: true }).click();
    await expectRows(app, 'trade', tickers);
    await expectRows(app, 'position', tickers);
    await app.getByRole('button', { name: 'Orders', exact: true }).click();
    await expectRows(app, 'order', ['MSFT']);
    const control = app.getByLabel('Orders ticker filter', { exact: true });
    await control.focus();
    await control.press('Home');
    await control.press('Enter');
    await expectRows(app, 'order', tickers);
    await popup.getByLabel('Trades ticker filter', { exact: true }).selectOption('selected');
    await expectRows(popup, 'trade', ['MSFT']);
    console.log('[ok] Real Sail context propagation, retained popout context, independent defaults/modes, tab persistence, exact filtering and keyboard control');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
