import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { CHECK_IDS, validateConfig, notificationAccounts, failureCode, fill, revealOrderActions, waitForModalClosed, newUserPage } from './browser_journey.mjs';

const config = () => ({ origin: 'https://localhost:18447', issuer: 'https://localhost:18446/realms/lab',
    frontendRoot: '/tmp/frontend', executablePath: '/usr/bin/chromium', profileDir: '/tmp/isolated-profile',
    users: { trader: { username: 'trader', password: 'private-password' }, reader: { username: 'reader', password: 'private-password' } },
    accounts: { trader: 62654, reader: 22214 }, security: 'IBM', quantity: 2, limitPrice: 100,
    expectedTradePrice: 99, expectedPositionQuantity: 12 });

test('the hosted driver only accepts the exact synthetic HTTPS fixture contract', () => {
    assert.equal(validateConfig(config()).quantity, 2);
    for (const change of [ { origin: 'http://localhost:18447' }, { origin: 'https://localhost:18447/path' },
        { issuer: 'https://user:secret@localhost/realms/lab' }, { issuer: 'https://localhost/realms/lab?other=1' },
        { quantity: 200000 }, { expectedPositionQuantity: 1 }, { profileDir: 'relative' },
        { accounts: { trader: 62654, reader: 62654 } }, { users: { trader: { username: 'x', password: 'private\nsecret' } } } ])
        assert.throws(() => validateConfig({ ...config(), ...change }));
});

test('notification observation rejects business payloads and invalid scopes', () => {
    const event = { topic: '/accounts/62654/trades', eventId: 'synthetic', eventKind: 'trade.settled' };
    assert.deepEqual(notificationAccounts({ events: [event] }), [62654]);
    for (const eventChange of [{ payload: { accountId: 62654 } }, { token: 'secret' }, { password: 'secret' },
        { topic: '/accounts/062654/trades' }, { topic: '/accounts/62654/executions' }, { topic: '/orders' }])
        assert.throws(() => notificationAccounts({ events: [{ ...event, ...eventChange }] }));
    assert.throws(() => notificationAccounts({ events: Array(65).fill(event) }));
});

test('evidence check vocabulary is fixed, unique and contains no credentials', () => {
    assert.equal(CHECK_IDS.length, 24);
    assert.equal(new Set(CHECK_IDS).size, CHECK_IDS.length);
    assert(CHECK_IDS.every(name => /^[a-z][a-z0-9_]{1,80}$/.test(name)));
});

test('configuration errors produce only bounded fixed diagnostics, never private input', async () => {
    const root = await mkdtemp(join(tmpdir(), 'traderx-browser-driver-test-'));
    try {
        const path = join(root, 'private.json');
        await writeFile(path, JSON.stringify({ ...config(), issuer: 'sentinel-private-value' }), { mode: 0o600 });
        const result = spawnSync(process.execPath, [new URL('./browser_journey.mjs', import.meta.url).pathname, '--config', path], { encoding: 'utf8' });
        assert.equal(result.status, 1);
        assert.deepEqual(JSON.parse(result.stdout), { status: 'failed', phase: 'configuration', checks: [], error: 'unexpected_error',
            diagnostics: { pageErrors: 0, cspErrors: 0, sessionStatus: 0, accountStatus: 0, orderStatus: 0, cancelStatus: 0, cancelPointerTarget: false, location: 'unknown', angularCodes: [], cspDirectives: [] } });
        assert.equal(result.stderr, '');
        assert(!result.stdout.includes('sentinel-private-value'));
        assert(!result.stdout.includes('private-password'));
    } finally { await rm(root, { recursive: true, force: true }); }
});

test('failure categories never echo private URLs, credentials or arbitrary exception messages', () => {
    assert.equal(failureCode({ name:'TimeoutError', message:'private-selector' }), 'timeout');
    assert.equal(failureCode(new Error('net::ERR_CERT_AUTHORITY_INVALID at https://private/?token=secret')), 'certificate_trust');
    assert.equal(failureCode(new Error('account_snapshot_missing')), 'account_snapshot_missing');
    assert.equal(failureCode(new Error('private-password')), 'unexpected_error');
});

test('form filling uses supported locator replacement without keyboard chord APIs', async () => {
    const calls = [];
    const page = { locator: selector => ({ fill: async value => calls.push({selector,value}) }) };
    await fill(page, '#password', 'private-password');
    await fill(page, '#orderQuantityField', 2);
    assert.deepEqual(calls, [{selector:'#password',value:'private-password'},{selector:'#orderQuantityField',value:'2'}]);
});

test('cancellation reveals virtualized action columns through the actual scroll viewport', async () => {
    const viewport = { scrollLeft:0, scrollWidth:1600 };
    const page = { $eval: async (selector, action) => {
        assert.equal(selector, 'app-order-blotter .ag-body-horizontal-scroll-viewport');
        action(viewport);
    }};
    await revealOrderActions(page);
    assert.equal(viewport.scrollLeft, 1600);
});

test('post-submit synchronization waits until modal and backdrop are removed', async () => {
    const original = globalThis.document;
    let overlay = {};
    globalThis.document = {querySelector: selector => {
        assert.equal(selector, 'modal-container, .modal-backdrop');
        return overlay;
    }};
    try {
        await waitForModalClosed({waitForFunction: async predicate => {
            assert.equal(predicate(), false);
            overlay = null;
            assert.equal(predicate(), true);
        }});
    } finally { globalThis.document = original; }
});

test('each user receives a new browser context with observers attached to its own page', async () => {
    const contexts = [];
    const browser = { createBrowserContext: async () => {
        const page = {setDefaultTimeout: () => {}, setDefaultNavigationTimeout: () => {}};
        const context = {newPage: async () => page, close: async () => {context.closed = true;}};
        contexts.push(context); return context;
    }};
    const observed = [];
    const trader = await newUserPage(browser, page => observed.push(['trader',page]));
    await trader.context.close();
    const reader = await newUserPage(browser, page => observed.push(['reader',page]));
    assert.equal(contexts.length, 2); assert.equal(trader.context.closed, true);
    assert.notEqual(trader.context, reader.context); assert.notEqual(trader.page, reader.page);
    assert.deepEqual(observed, [['trader',trader.page],['reader',reader.page]]);
});

test('a failed user-page initialization closes only its newly owned context', async () => {
    let closed = false;
    const context = {newPage: async () => {throw new Error('fixed_failure');}, close: async () => {closed = true;}};
    await assert.rejects(newUserPage({createBrowserContext: async () => context}, () => {}), /fixed_failure/);
    assert.equal(closed, true);
});
