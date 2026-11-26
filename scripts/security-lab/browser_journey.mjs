/** Hosted real-browser journey. Credentials enter only the Keycloak login form. */
import { readFile, lstat } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { isAbsolute, join } from 'node:path';
import { createInterface } from 'node:readline';
import { pathToFileURL } from 'node:url';
import { setTimeout as delay } from 'node:timers/promises';

const ORDER = /^ord-013-[0-9]{1,24}$/;
const ACCOUNT = Number.isSafeInteger;
const TIMEOUT = 30000;
export const CHECK_IDS = Object.freeze([
    'trader_account_snapshot_scoped', 'trader_account_menu_scoped',
    'session_cookie_secure_httponly', 'browser_script_has_no_session_cookie_or_stored_tokens',
    'missing_csrf_order_rejected',
    'actual_limit_order_form_and_open_grid', 'matched_order_leaves_open_grid',
    'actual_scoped_broker_notifications_received', 'mounted_blotters_refetch_after_notifications',
    'settled_trade_visible_in_actual_grid', 'settled_position_and_live_valuation_visible',
    'actual_grid_cancel_button_updates_open_orders', 'trader_logout_clears_private_components', 'trader_logout_retires_browser_cookie',
    'reader_account_snapshot_scoped', 'reader_account_menu_scoped', 'reader_cross_account_snapshot_denied',
    'reader_order_rejected_by_api', 'reader_write_denial_visible_in_ui',
    'reader_logout_clears_private_components', 'reader_logout_retires_browser_cookie',
    'no_browser_bearer_header', 'browser_requests_stay_on_approved_origins', 'no_unexpected_browser_or_csp_errors',
]);
const checks = [];
let phase = 'configuration';
const diagnostics = { pageErrors: 0, cspErrors: 0, sessionStatus: 0, accountStatus: 0,
    orderStatus: 0, cancelStatus: 0, location: 'unknown', angularCodes: [], cspDirectives: [] };

export const FAILURE_CODES = Object.freeze([
    'timeout', 'certificate_trust', 'tls_failure', 'connection_unavailable', 'unexpected_error',
    'unsupported_api', 'element_not_clickable', 'context_destroyed',
    'check_failed', 'invalid_configuration', 'invalid_origin', 'invalid_issuer', 'invalid_private_path',
    'invalid_credentials', 'invalid_account', 'distinct_accounts_required', 'unexpected_fixture_terms',
    'absolute_configuration_required', 'private_configuration_required', 'invalid_notification_response',
    'invalid_notification_topic', 'notification_business_payload', 'invalid_stage_reply', 'stage_not_approved',
    'coordinator_closed', 'coordinator_timeout', 'invalid_order_id', 'visible_control_missing',
    'unexpected_login_origin', 'unexpected_callback_origin', 'account_snapshot_missing', 'account_label_missing',
    'order_submission_rejected', 'invalid_created_order', 'logout_unconfirmed', 'initial_settlement_snapshots_missing',
    'actual_broker_notifications_missing', 'notification_snapshots_not_refreshed', 'settled_trade_not_rendered',
    'position_valuation_not_rendered', 'cancel_rejected', 'configuration_argument_required',
]);

export function failureCode(error) {
    const message = typeof error?.message === 'string' ? error.message : '';
    if (FAILURE_CODES.includes(message)) return message;
    if (error?.name === 'TimeoutError') return 'timeout';
    if (error?.name === 'TypeError' && /is not a function/.test(message)) return 'unsupported_api';
    if (/not clickable|not an Element|not of type HTMLElement/i.test(message)) return 'element_not_clickable';
    if (/Execution context was destroyed|Cannot find context with specified id/i.test(message)) return 'context_destroyed';
    if (/net::ERR_CERT_[A-Z_]+/.test(message)) return 'certificate_trust';
    if (/net::ERR_SSL_[A-Z_]+/.test(message)) return 'tls_failure';
    if (/net::ERR_CONNECTION_(?:REFUSED|CLOSED|RESET|TIMED_OUT)/.test(message)) return 'connection_unavailable';
    return 'unexpected_error';
}

function demand(condition, code) { if (!condition) throw new Error(code); }
function check(condition, name) { demand(CHECK_IDS.includes(name) && condition, 'check_failed'); checks.push(name); }
function write(value) { process.stdout.write(JSON.stringify(value) + '\n'); }

export function validateConfig(value) {
    demand(value && typeof value === 'object' && !Array.isArray(value), 'invalid_configuration');
    const origin = new URL(value.origin);
    const issuer = new URL(value.issuer);
    demand(origin.protocol === 'https:' && origin.origin === value.origin && !origin.username && !origin.password, 'invalid_origin');
    demand(issuer.protocol === 'https:' && !issuer.username && !issuer.password && !issuer.search && !issuer.hash &&
        /^\/realms\/[A-Za-z0-9_-]{1,64}$/.test(issuer.pathname), 'invalid_issuer');
    for (const field of ['frontendRoot', 'executablePath', 'profileDir'])
        demand(typeof value[field] === 'string' && isAbsolute(value[field]), 'invalid_private_path');
    for (const role of ['trader', 'reader']) {
        const user = value.users?.[role];
        for (const field of ['username', 'password'])
            demand(typeof user?.[field] === 'string' && user[field].length > 0 && user[field].length <= 256 && !/[\r\n]/.test(user[field]), 'invalid_credentials');
        demand(ACCOUNT(value.accounts?.[role]) && value.accounts[role] > 0, 'invalid_account');
    }
    demand(value.accounts.trader !== value.accounts.reader, 'distinct_accounts_required');
    demand(value.security === 'IBM' && value.quantity === 2 && value.limitPrice === 100 && value.expectedTradePrice === 99 &&
        ACCOUNT(value.expectedPositionQuantity) && value.expectedPositionQuantity >= value.quantity, 'unexpected_fixture_terms');
    return value;
}

async function loadConfig(filename) {
    demand(isAbsolute(filename), 'absolute_configuration_required');
    const info = await lstat(filename);
    demand(info.isFile() && !info.isSymbolicLink() && (info.mode & 0o777) === 0o600 &&
        info.uid === process.getuid() && info.size <= 65536, 'private_configuration_required');
    return validateConfig(JSON.parse(await readFile(filename, 'utf8')));
}

async function until(predicate, code, timeout = TIMEOUT) {
    const deadline = Date.now() + timeout;
    while (Date.now() < deadline) {
        if (await predicate()) return;
        await delay(50);
    }
    throw new Error(code);
}

export function notificationAccounts(value) {
    demand(value && typeof value === 'object' && Array.isArray(value.events) && value.events.length <= 64,
        'invalid_notification_response');
    return value.events.map(event => {
        const match = /^\/accounts\/([1-9][0-9]*)\/(trades|positions)$/.exec(event.topic);
        demand(match && ACCOUNT(Number(match[1])), 'invalid_notification_topic');
        demand(!('payload' in event) && !('password' in event) && !('token' in event), 'notification_business_payload');
        return Number(match[1]);
    });
}

function coordinator() {
    const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });
    let pending;
    lines.on('line', line => {
        if (!pending) return;
        const current = pending; pending = undefined;
        try {
            demand(line.length <= 1024, 'invalid_stage_reply');
            const value = JSON.parse(line);
            demand(value && value.ok === true && Object.keys(value).length === 1, 'stage_not_approved');
            current.resolve();
        } catch { current.reject(new Error('invalid_stage_reply')); }
    });
    lines.on('close', () => pending?.reject(new Error('coordinator_closed')));
    return {
        async stage(stage, orderId) {
            demand(ORDER.test(orderId), 'invalid_order_id');
            phase = stage;
            await new Promise((resolve, reject) => {
                const timer = setTimeout(() => { pending = undefined; reject(new Error('coordinator_timeout')); }, 60000);
                pending = { resolve: () => { clearTimeout(timer); resolve(); }, reject: error => { clearTimeout(timer); reject(error); } };
                write({ stage, orderId });
            });
        },
        close() { lines.close(); },
    };
}

async function clickText(page, selector, text, contains = false) {
    await page.waitForFunction((selector, text, contains) => [...document.querySelectorAll(selector)]
        .some(element => contains ? element.textContent?.includes(text) : element.textContent?.trim() === text),
    { timeout: TIMEOUT }, selector, text, contains);
    for (const element of await page.$$(selector)) {
        const label = await element.evaluate(item => item.textContent?.trim() || '');
        if (contains ? label.includes(text) : label === text) { await element.click(); return; }
        await element.dispose();
    }
    throw new Error('visible_control_missing');
}

export async function fill(page, selector, value) {
    // Puppeteer.press accepts one KeyInput, not Playwright-style Control+A chords.
    // The supported locator API waits for an editable element and replaces its value.
    await page.locator(selector).fill(String(value));
}

async function login(page, config, role, observed) {
    phase = `${role}_login_initial_page`;
    observed.accounts = null;
    await page.goto(config.origin, { waitUntil: 'domcontentloaded' });
    phase = `${role}_login_signin_link`;
    await page.waitForSelector('a[href="/login"]', { visible: true });
    phase = `${role}_login_provider_navigation`;
    await Promise.all([page.waitForNavigation({ waitUntil: 'domcontentloaded' }), page.click('a[href="/login"]')]);
    demand(new URL(page.url()).origin === new URL(config.issuer).origin, 'unexpected_login_origin');
    phase = `${role}_login_username`;
    await fill(page, '#username', config.users[role].username);
    phase = `${role}_login_password`;
    await fill(page, '#password', config.users[role].password);
    phase = `${role}_login_callback`;
    await Promise.all([page.waitForNavigation({ waitUntil: 'domcontentloaded' }), page.click('#kc-login')]);
    await page.waitForSelector('app-trade #createOrderBtn', { visible: true });
    demand(new URL(page.url()).origin === config.origin, 'unexpected_callback_origin');
    phase = `${role}_login_accounts`;
    await until(() => Array.isArray(observed.accounts), 'account_snapshot_missing');
    check(observed.accounts.length === 1 && Number(observed.accounts[0].id) === config.accounts[role], `${role}_account_snapshot_scoped`);
    const label = observed.accounts[0].displayName;
    demand(typeof label === 'string' && label.length > 0, 'account_label_missing');
    phase = `${role}_login_account_menu`;
    await page.click('app-trade app-ngx-dropdown button.dropdown-toggle');
    const labels = await page.$$eval('app-trade app-ngx-dropdown [role="menuitem"]', items => items.map(item => item.textContent?.trim()));
    check(labels.length === 2 && labels.includes('All Accounts') && labels.includes(label), `${role}_account_menu_scoped`);
    await clickText(page, 'app-trade app-ngx-dropdown [role="menuitem"]', label);
    await page.waitForFunction(label => document.querySelector('app-trade app-ngx-dropdown button')?.textContent?.includes(label), {}, label);
}

async function submitOrder(page, config, limitPrice, accepted = true) {
    const flow = phase === 'cancel_order' ? 'cancel_order' : accepted ? 'trader_order' : 'reader_order';
    phase = `${flow}_open_ticket`;
    await page.click('#createOrderBtn');
    phase = `${flow}_stock_input`;
    // A preset can retain the selected security. Clear it so the real typeahead
    // receives a new input event even when the requested ticker is unchanged.
    await fill(page, '#order-stock-input', '');
    await fill(page, '#order-stock-input', config.security);
    phase = `${flow}_typeahead`;
    await page.waitForSelector('typeahead-container .dropdown-item', { visible: true });
    await clickText(page, 'typeahead-container .dropdown-item', config.security, true);
    phase = `${flow}_terms`;
    await page.click('label[for="orderBuyButton"]');
    await fill(page, '#orderQuantityField', config.quantity);
    await fill(page, '#orderStrikeField', limitPrice);
    const responsePromise = page.waitForResponse(response => new URL(response.url()).origin === config.origin &&
        new URL(response.url()).pathname === '/api/order-matcher/orders' && response.request().method() === 'POST');
    phase = `${flow}_submit_click`;
    await page.click('#createOrderButton');
    phase = `${flow}_submit_response`;
    const response = await responsePromise;
    if (!accepted) {
        check(response.status() === 403, 'reader_order_rejected_by_api');
        phase = `${flow}_denial_message`;
        await page.waitForFunction(() => document.querySelector('app-trade')?.textContent?.includes('Order was not accepted.'));
        check(true, 'reader_write_denial_visible_in_ui');
        return null;
    }
    demand([200, 201].includes(response.status()), 'order_submission_rejected');
    const order = await response.json();
    demand(ORDER.test(order?.orderId) && Number(order.accountId) === config.accounts.trader, 'invalid_created_order');
    phase = `${flow}_open_row`;
    await page.waitForSelector(`app-order-blotter .ag-center-cols-container .ag-row[row-id="${order.orderId}"]`, { visible: true });
    return order.orderId;
}

async function logout(page, config, role) {
    const responsePromise = page.waitForResponse(response => response.url() === config.origin + '/logout' && response.request().method() === 'POST');
    await clickText(page, 'app-root button', 'Sign out');
    demand((await responsePromise).status() === 200, 'logout_unconfirmed');
    await page.waitForSelector('a[href="/login"]', { visible: true });
    check(await page.$('app-trade') === null, `${role}_logout_clears_private_components`);
    const status = await page.evaluate(async () => (await fetch('/api/order-matcher/orders')).status);
    check(status === 401, `${role}_logout_retires_browser_cookie`);
}

async function gridValues(page, scope) {
    return page.$$eval(`${scope} .ag-center-cols-container .ag-row`, rows => rows.map(row =>
        Object.fromEntries([...row.querySelectorAll('[col-id]')].map(cell => [cell.getAttribute('col-id'), cell.textContent?.trim()]))));
}

export async function revealOrderActions(page) {
    // AG Grid virtualizes horizontal columns. Scroll the real viewport instead
    // of asking a locator to find a button that has not been rendered yet.
    await page.$eval('app-order-blotter .ag-body-horizontal-scroll-viewport', element => {
        element.scrollLeft = element.scrollWidth;
    });
}

function number(value) { return Number(String(value ?? '').replace(/[^0-9.-]/g, '')); }

export async function run(config) {
    const require = createRequire(join(config.frontendRoot, 'package.json'));
    const puppeteer = require('puppeteer');
    const ipc = coordinator();
    let browser;
    try {
        phase = 'browser_launch';
        browser = await puppeteer.launch({ executablePath: config.executablePath, headless: true,
            userDataDir: config.profileDir, args: ['--no-sandbox', '--disable-dev-shm-usage'],
            defaultViewport: { width: 1600, height: 1100 } });
        const context = browser.defaultBrowserContext();
        const page = await context.newPage();
        page.setDefaultTimeout(TIMEOUT); page.setDefaultNavigationTimeout(TIMEOUT);
        const observed = { accounts: null, events: [], tradeResponses: 0, positionResponses: 0,
            tradeAtNotification: null, positionsAtNotification: null,
            errors: 0, forbiddenHeaders: 0, externalRequests: 0, csp: 0 };
        const pendingObservers = new Set();
        const track = task => {
            pendingObservers.add(task);
            task.catch(() => observed.errors++).finally(() => pendingObservers.delete(task));
        };
        const allowedOrigins = new Set([config.origin, new URL(config.issuer).origin]);
        let expectedAccount = config.accounts.trader;
        page.on('framenavigated', frame => {
            if (frame !== page.mainFrame()) return;
            try { const origin = new URL(frame.url()).origin;
                diagnostics.location = origin === config.origin ? 'app' : origin === new URL(config.issuer).origin ? 'issuer' : 'other';
            } catch { diagnostics.location = 'unknown'; }
        });
        page.on('pageerror', error => {
            observed.errors++; diagnostics.pageErrors = Math.min(1000, diagnostics.pageErrors + 1);
            for (const code of String(error?.message ?? '').match(/\bNG[0-9]{4,6}\b/g) ?? [])
                if (!diagnostics.angularCodes.includes(code) && diagnostics.angularCodes.length < 8) diagnostics.angularCodes.push(code);
        });
        page.on('console', message => {
            const text = message.text();
            if (/Content Security Policy|Refused to (?:execute|load|apply)/i.test(text)) {
                observed.csp++; diagnostics.cspErrors = Math.min(1000, diagnostics.cspErrors + 1);
                for (const name of ['default-src','script-src','script-src-elem','style-src','style-src-elem','font-src','img-src','connect-src','frame-src','frame-ancestors','form-action','base-uri','object-src'])
                    if (new RegExp('\\b'+name+'\\b').test(text) && !diagnostics.cspDirectives.includes(name)) diagnostics.cspDirectives.push(name);
            }
            else if (message.type() === 'error' && !/^Failed to load resource: the server responded with a status of (401|403)\b/.test(text)) {
                if (phase === 'reader_denials' || phase.startsWith('reader_order_')) track((async () => {
                    // The inherited API service logs HttpErrorResponse on the
                    // deliberately denied reader order. Inspect status only;
                    // never export the object, URL, request or response body.
                    const expected = await Promise.all(message.args().map(argument => argument.evaluate(value =>
                        value?.status === 403 && value?.name === 'HttpErrorResponse')));
                    if (!expected.some(Boolean)) observed.errors++;
                })());
                else observed.errors++;
            }
        });
        page.on('requestfailed', request => { if (request.failure()?.errorText !== 'net::ERR_ABORTED') observed.errors++; });
        page.on('request', request => {
            const url = new URL(request.url());
            if (url.protocol !== 'data:' && !allowedOrigins.has(url.origin)) observed.externalRequests++;
            if (url.origin === config.origin && request.headers().authorization) observed.forbiddenHeaders++;
        });
        page.on('response', response => track((async () => {
            try {
                const url = new URL(response.url());
                if (url.origin === config.origin && url.pathname === '/session') diagnostics.sessionStatus = response.status();
                if (url.origin === config.origin && url.pathname === '/api/account-service/account/') diagnostics.accountStatus = response.status();
                if (url.origin === config.origin && url.pathname === '/api/order-matcher/orders' && response.request().method() === 'POST') diagnostics.orderStatus = response.status();
                if (url.origin === config.origin && /^\/api\/order-matcher\/orders\/ord-013-[0-9]+\/cancel$/.test(url.pathname)) diagnostics.cancelStatus = response.status();
                if (url.origin !== config.origin || response.status() !== 200) return;
                if (url.pathname === '/api/account-service/account/') observed.accounts = await response.json();
                if (url.pathname === '/events') {
                    const value = await response.json();
                    for (const account of notificationAccounts(value)) {
                        if (account !== expectedAccount) observed.errors++;
                    }
                    observed.events.push(...value.events.map(event => event.topic));
                    if (value.events.some(event => event.topic === `/accounts/${expectedAccount}/trades`))
                        observed.tradeAtNotification = observed.tradeResponses;
                    if (value.events.some(event => event.topic === `/accounts/${expectedAccount}/positions`))
                        observed.positionsAtNotification = observed.positionResponses;
                }
                if (url.pathname === `/api/position-service/trades/${expectedAccount}`) observed.tradeResponses++;
                if (url.pathname === `/api/position-service/positions/${expectedAccount}`) observed.positionResponses++;
            } catch { if (phase !== 'logout' && !phase.startsWith('reader_login')) observed.errors++; }
        })()));

        await login(page, config, 'trader', observed);
        const cookies = await context.cookies();
        const sessionCookie = cookies.find(cookie => cookie.name === '__Host-traderx-session');
        check(sessionCookie?.secure && sessionCookie.httpOnly && sessionCookie.sameSite === 'Lax', 'session_cookie_secure_httponly');
        check(await page.evaluate(() => !document.cookie.includes('__Host-traderx-session') &&
            ![...Object.values(localStorage), ...Object.values(sessionStorage)].some(value => /(?:access_token|refresh_token|id_token|Bearer\s|eyJ[A-Za-z0-9_-]+\.)/.test(value))), 'browser_script_has_no_session_cookie_or_stored_tokens');

        phase = 'trader_order';
        const missingCsrf = await page.evaluate(async accountId => (await fetch('/api/order-matcher/orders', {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ accountId, security: 'IBM', side: 'Buy', quantity: 2, limitPrice: 1 }),
        })).status, config.accounts.trader);
        check(missingCsrf === 403, 'missing_csrf_order_rejected');
        const orderId = await submitOrder(page, config, config.limitPrice);
        check(true, 'actual_limit_order_form_and_open_grid');
        await ipc.stage('ready_for_price', orderId);
        await page.waitForSelector(`app-order-blotter .ag-row[row-id="${orderId}"]`, { hidden: true });
        check(true, 'matched_order_leaves_open_grid');
        await clickText(page, 'app-trade .nav-pills button', 'Trades / Positions');
        await page.waitForSelector('app-trade-blotter');
        await until(() => observed.tradeResponses > 0 && observed.positionResponses > 0, 'initial_settlement_snapshots_missing');
        const before = { events: observed.events.length, trades: observed.tradeResponses, positions: observed.positionResponses };
        observed.tradeAtNotification = null; observed.positionsAtNotification = null;
        await ipc.stage('ready_for_delivery', orderId);
        phase = 'settled_grids';
        await until(() => observed.events.slice(before.events).includes(`/accounts/${config.accounts.trader}/trades`) &&
            observed.events.slice(before.events).includes(`/accounts/${config.accounts.trader}/positions`), 'actual_broker_notifications_missing');
        check(true, 'actual_scoped_broker_notifications_received');
        await until(() => observed.tradeAtNotification !== null && observed.positionsAtNotification !== null &&
            observed.tradeResponses > observed.tradeAtNotification && observed.positionResponses > observed.positionsAtNotification, 'notification_snapshots_not_refreshed');
        check(true, 'mounted_blotters_refetch_after_notifications');
        await until(async () => (await gridValues(page, 'app-trade-blotter')).some(row => row.security === config.security &&
            number(row.quantity) === config.quantity && number(row.price) === config.expectedTradePrice && row.side === 'Buy' && /settled/i.test(row.state)), 'settled_trade_not_rendered');
        check(true, 'settled_trade_visible_in_actual_grid');
        await until(async () => (await gridValues(page, 'app-position-blotter')).some(row => row.security === config.security &&
            number(row.quantity) === config.expectedPositionQuantity && number(row.marketValue) === config.expectedPositionQuantity * config.expectedTradePrice), 'position_valuation_not_rendered');
        check(true, 'settled_position_and_live_valuation_visible');

        phase = 'cancel_order';
        const cancelOrderId = await submitOrder(page, config, 1);
        phase = 'cancel_order_scroll';
        await revealOrderActions(page);
        const cancelResponse = page.waitForResponse(response => response.url() === config.origin + `/api/order-matcher/orders/${cancelOrderId}/cancel` && response.request().method() === 'POST');
        phase = 'cancel_order_click';
        await page.locator(`app-order-blotter .ag-row[row-id="${cancelOrderId}"] [col-id="cancel"] button`).click();
        phase = 'cancel_order_response';
        demand((await cancelResponse).status() === 200, 'cancel_rejected');
        phase = 'cancel_order_removed';
        await page.waitForSelector(`app-order-blotter .ag-row[row-id="${cancelOrderId}"]`, { hidden: true });
        check(true, 'actual_grid_cancel_button_updates_open_orders');
        phase = 'logout'; await logout(page, config, 'trader');

        expectedAccount = config.accounts.reader;
        await login(page, config, 'reader', observed);
        phase = 'reader_denials';
        const foreign = await page.evaluate(async account => (await fetch(`/api/position-service/positions/${account}`)).status, config.accounts.trader);
        check(foreign === 403, 'reader_cross_account_snapshot_denied');
        await submitOrder(page, config, 1, false);
        phase = 'logout'; await logout(page, config, 'reader');
        await Promise.all([...pendingObservers]);
        check(observed.forbiddenHeaders === 0, 'no_browser_bearer_header');
        check(observed.externalRequests === 0, 'browser_requests_stay_on_approved_origins');
        check(observed.csp === 0 && observed.errors === 0, 'no_unexpected_browser_or_csp_errors');
        return { status: 'passed', checks, orderId, cancelOrderId };
    } finally {
        ipc.close();
        if (browser) await browser.close();
    }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
    try {
        demand(process.argv.length === 4 && process.argv[2] === '--config', 'configuration_argument_required');
        write(await run(await loadConfig(process.argv[3])));
    } catch (error) {
        write({ status: 'failed', phase, checks, error: failureCode(error), diagnostics });
        process.exitCode = 1;
    }
}
