"""Opt-in pinned Angular consumer candidate; no live identity or deployment cutover."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
from render_account_security import ROOT, PROFILE, replace_once
from render_order_consumers import apply as apply_order_consumers
from render_trading_ui import apply as apply_trading_ui
from render_portfolio_consumers import apply as apply_portfolio_consumers

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
    # Fail on unexpected pinned input before replacing the transport candidate.
    if 'export class TradeFeedService' not in source or 'private connect() {' not in source:
        raise ValueError('Pinned feed boundary changed')
    return (OVERLAY/'broker-feed.service.ts').read_text().replace("from './broker-notifications'", "from '../security/broker-notifications'")


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
    angular=target/'angular.json';configuration=json.loads(angular.read_text())
    configuration['projects']['main-application']['architect']['build']['configurations']['production']['optimization']={
        'scripts':True,'styles':{'minify':True,'inlineCritical':False},'fonts':False}
    angular.write_text(json.dumps(configuration,indent=2)+'\n')
    index=target/'main/index.html';index.write_text(replace_once(index.read_text(),'<base href="." />','<base href="/" />'))
    package=target/'package.json';metadata=json.loads(package.read_text())
    metadata['scripts']['build']=replace_once(metadata['scripts']['build'],'--base-href=.','--base-href=/')
    metadata['scripts']['build']=replace_once(metadata['scripts']['build'],'--output-path=./dist','--output-path=./dist/main-application')
    package.write_text(json.dumps(metadata,indent=2)+'\n')
    for name in ('trade','position'):
        path=app/f'trade/{name}-blotter/{name}-blotter.component.ts'
        path.write_text(blotter(path.read_text(),name=='position'))
    path=app/'service/trade-feed.service.ts'; path.write_text(feed(path.read_text()))
    apply_order_consumers(target)
    apply_trading_ui(target)
    apply_portfolio_consumers(target)
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
    <p *ngIf="session.logoutUnconfirmed" role="alert">Your local view is cleared, but server sign-out could not be confirmed. Reload and try signing out again.</p>
    <a *ngIf="state === 'signed-out'" href="/login">Sign in with Keycloak</a>
  </main>
  <ng-container *ngIf="state === 'signed-in'">
    <p>Signed in as {{ session.subject }} <button type="button" (click)="session.logout()">Sign out</button></p>
    <p role="status">Authenticated limit orders and account-scoped settlement notifications. Orders and quotes refresh through bounded HTTP snapshots.</p>
'''+path.read_text()+'''
  </ng-container>
</ng-container>
''')
    dest=app/'security'; dest.mkdir(exist_ok=True)
    for path in OVERLAY.glob('*.ts'):
        if path.name != 'broker-feed.service.ts': (dest/path.name).write_bytes(path.read_bytes())
    inputs=[Path(__file__).resolve(),ROOT/'scripts/security-lab/render_account_security.py',
        ROOT/'scripts/security-lab/render_order_consumers.py',ROOT/'scripts/security-lab/render_trading_ui.py',
        ROOT/'scripts/security-lab/render_portfolio_consumers.py',
        PROFILE/'baseline.lock.json',*sorted(OVERLAY.glob('*.ts'))]
    manifest={'scope':'Cookie-session, mediated broker and snapshot consumer source candidate; cumulative deployment/trading remains pending',
        'generated_commit':baseline['generated_commit'],
        'inputs':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs},
        'files':{str(p.relative_to(target)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(target.rglob('*')) if p.is_file()}}
    (target/'security-generation.json').write_text(json.dumps(manifest,indent=2)+'\n')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--output-dir',type=Path,required=True)
    render(parser.parse_args().output_dir)
