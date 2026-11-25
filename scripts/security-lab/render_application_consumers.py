"""Opt-in pinned Angular consumer candidate; no live identity or deployment cutover."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from render_account_security import ROOT, PROFILE, replace_once

OVERLAY = ROOT / 'specs/019-traderx-security-lab/generation/application-consumers'


def section(source, start, end, replacement):
    if source.count(start) != 1 or source.count(end) != 1:
        raise ValueError('Pinned consumer boundary changed')
    a, b = source.index(start), source.index(end)
    if a >= b: raise ValueError('Invalid consumer boundary')
    return source[:a] + replacement + '\n\n' + source[b:]


def blotter(source, position=False):
    kind = 'Position' if position else 'Trade'
    rows = 'positions' if position else 'trades'
    source = "import { SettlementSnapshot } from 'main/app/security/settlement-snapshot';\n" + source
    marker = '  private readonly marketPriceByTicker' if position else '    private readonly baseColumns'
    source = replace_once(source, marker, f'  private settlementSnapshot?: SettlementSnapshot<{kind}>;\n'+marker)
    apply = '''this.positions = all ? this.mergePositionsBySecurity(scoped) : scoped.map(row => this.recomputePosition(row));
        this.setGridRowData(this.positions); this.emitSummary();
        this.bootstrapSnapshotPrices(this.positions.map((row: any) => row.security));''' if position else '''this.trades = scoped.map(row => this.withAccountDisplay(row));
        if (this.gridApi) this.gridApi.setGridOption('rowData', this.trades);'''
    pre = '''this.marketPriceByTicker.clear(); this.marketPriceAsOfByTicker.clear(); this.openPriceByTicker.clear();
    this.priceStreamUnsubscribeFn?.();
    this.priceStreamUnsubscribeFn = this.tradeFeed.subscribe('pricing.*', (tick: PriceTick) => this.updateMarketPrice(tick));''' if position else ''
    clear_grid = 'this.setGridRowData([]); this.emitSummary();' if position else "if (this.gridApi) this.gridApi.setGridOption('rowData', []);"
    new = f'''  private loadScope() {{
    this.clearSubscriptions();
    this.{rows} = []; this.pending{kind if position else 'Trades'} = [];
    {clear_grid}
    this.isPending = true;
    {pre}
    const all = this.allAccountsMode;
    const ids = new Set((all ? this.accountIds : [this.account?.id]).filter((id): id is number => Number.isSafeInteger(id) && Number(id) > 0));
    if (!ids.size) {{ this.isPending = false; return; }}
    const account = [...ids][0];
    const snapshot = new SettlementSnapshot<{kind}>(
      () => all ? this.tradeService.getAll{kind}s() : this.tradeService.get{kind}s(account),
      rows => {{
        const scoped = rows.filter(row => row && ids.has(Number((row as any).accountId ?? (row as any).accountid)));
        {apply}
        this.isPending = false;
      }});
    this.settlementSnapshot = snapshot;
    for (const id of ids) this.socketUnSubscribeFns.push(
      this.tradeFeed.subscribeSettlement(`/accounts/${{id}}/{rows}`, () => snapshot.refresh()));
    const connection = this.tradeFeed.connectionState$.subscribe(state => {{ if (state === 'connected') snapshot.refresh(); }});
    this.socketUnSubscribeFns.push(() => connection.unsubscribe());
    snapshot.refresh();
  }}'''
    start = '  private loadScope() {' if position else '    private loadScope() {'
    end = '  private bootstrapSnapshotPrices(' if position else '    private clearSubscriptions() {'
    if position: new += '\n\n  private refreshAllAccountsPositions() { this.settlementSnapshot?.refresh(); }'
    source = section(source, start, end, new)
    clear = '  private clearSubscriptions() {' if position else '    private clearSubscriptions() {'
    return replace_once(source, clear, clear+'\n    this.settlementSnapshot?.dispose(); this.settlementSnapshot = undefined;')


def feed(source):
    source = section(source, '    private connect() {', '    private resolveWebSocketUrl(', '''    private connect() {
        // Live authenticated broker mediation/issuance is a separate acceptance gate.
        // Never fall back to the C3 anonymous WebSocket in this candidate.
        this.connectionStateSubject.next('disconnected');
    }''')
    source = "import { settlementMatches } from 'main/app/security/settlement-snapshot';\n" + source
    source = replace_once(source, 'type SubscriptionRecord = {', 'type SubscriptionRecord = {\n    settlement?: boolean;')
    source = replace_once(source, 'this.dispatchMessage(this.pendingMsg.sid, payload);', 'this.dispatchMessage(this.pendingMsg.sid, payload, this.pendingMsg.subject);')
    source = replace_once(source, 'private dispatchMessage(sid: number, payloadText: string)', 'private dispatchMessage(sid: number, payloadText: string, subject: string)')
    source = replace_once(source, '            const parsed = JSON.parse(payloadText);', '''            const parsed = JSON.parse(payloadText);
            if (record.settlement) {
                if (subject === record.topic && settlementMatches(subject, parsed)) record.callback();
                return;
            }''')
    source = replace_once(source, "            console.error('Failed to parse NATS websocket payload', err);", "            console.warn('Invalid message rejected');")
    return replace_once(source, '    public unSubscribe(', '''    public subscribeSettlement(topic: string, callback: () => void): () => void {
        if (!/^\\/accounts\\/[1-9][0-9]*\\/(trades|positions)$/.test(topic)) throw new Error('Explicit settlement account required');
        const sid = this.nextSid++;
        this.subscriptions.set(sid, { sid, topic, callback, settlement: true });
        this.connect();
        this.sendRaw(`SUB ${topic} ${sid}\\r\\n`);
        this.sendRaw('PING\\r\\n');
        return () => this.removeSubscription(sid);
    }

    public unSubscribe(''')


def render(target):
    target=Path(target).resolve(); baseline=json.loads((PROFILE/'baseline.lock.json').read_text())
    prefix='web-front-end/angular'
    data=subprocess.run(['git','archive',baseline['generated_commit'],prefix],cwd=ROOT,capture_output=True,check=True,timeout=30).stdout
    target.mkdir(parents=True,exist_ok=False)
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.isfile():
                relative=Path(member.name).relative_to(prefix)
                if '..' in relative.parts: raise ValueError('Invalid pinned frontend member')
                dest=target/relative; dest.parent.mkdir(parents=True,exist_ok=True)
                dest.write_bytes(archive.extractfile(member).read()); dest.chmod(member.mode & 0o777)
    app=target/'main/app'
    for name in ('trade','position'):
        path=app/f'trade/{name}-blotter/{name}-blotter.component.ts'
        path.write_text(blotter(path.read_text(),name=='position'))
    path=app/'service/trade-feed.service.ts'; path.write_text(feed(path.read_text()))
    path=app/'app.module.ts'
    source="import { browserSessionInterceptor } from './security/browser-session';\n"+path.read_text()
    source=replace_once(source,'provideHttpClient, withInterceptorsFromDi,','provideHttpClient, withInterceptors, withInterceptorsFromDi,')
    path.write_text(replace_once(source,'provideHttpClient(withInterceptorsFromDi(), withJsonpSupport())','provideHttpClient(withInterceptors([browserSessionInterceptor]), withInterceptorsFromDi(), withJsonpSupport())'))
    path=app/'app.component.ts'
    source="import { BrowserSession } from './security/browser-session';\n"+path.read_text()
    source=replace_once(source,'constructor(public themeService: ThemeService) { }','''constructor(public themeService: ThemeService, public session: BrowserSession) { session.refresh(); }

    ngOnDestroy() { this.session.clear(); }''')
    path.write_text(source)
    path=app/'app.component.html'
    path.write_text('''<ng-container *ngIf="session.state$ | async as state">
  <main *ngIf="state !== 'signed-in'" aria-live="polite">
    <h1>TraderX Security Lab</h1>
    <p *ngIf="state === 'checking'">Checking your session…</p>
    <a *ngIf="state === 'signed-out'" href="/login">Sign in with Keycloak</a>
  </main>
  <ng-container *ngIf="state === 'signed-in'">
    <p>Signed in as {{ session.subject }} <button type="button" (click)="session.logout()">Sign out</button></p>
    <p role="status">Authenticated API candidate. Live market and settlement notifications await the scoped broker checkpoint.</p>
'''+path.read_text()+'''
  </ng-container>
</ng-container>
''')
    dest=app/'security'; dest.mkdir(exist_ok=True)
    for path in OVERLAY.glob('*.ts'): (dest/path.name).write_bytes(path.read_bytes())
    inputs=[Path(__file__).resolve(),ROOT/'scripts/security-lab/render_account_security.py',PROFILE/'baseline.lock.json',*sorted(OVERLAY.glob('*.ts'))]
    manifest={'scope':'Cookie-session and snapshot consumer source candidate; authenticated broker and cumulative trading remain pending',
        'generated_commit':baseline['generated_commit'],
        'inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
        'files':{str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.rglob('*')) if p.is_file()}}
    (target/'security-generation.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output-dir',type=Path,required=True)
    render(parser.parse_args().output_dir)
