'use strict';
let state, selected = 'platform', runId = null, tab = 'experiments';
const $ = id => document.getElementById(id);
const text = (tag, value, cls) => { const el = document.createElement(tag); el.textContent = value; if (cls) el.className = cls; return el; };
const nameFor = id => state.scenarios.find(s => s.id === id)?.name || id;
const date = value => new Date(value).toLocaleString();
function showError(message) { $('error').textContent = message; $('error').hidden = !message; }
async function api(path, options) { const res = await fetch(path, options); const data = await res.json(); if (!res.ok) throw new Error(data.error || 'Request failed'); return data; }
function switchTab(id) { tab = id; document.querySelectorAll('.tab').forEach(el => el.hidden = el.id !== id); document.querySelectorAll('.nav').forEach(el => { el.classList.toggle('active', el.dataset.tab === id); el.setAttribute('aria-current', el.dataset.tab === id ? 'page' : 'false'); }); }
document.querySelectorAll('.nav').forEach(el => el.addEventListener('click', () => switchTab(el.dataset.tab)));
function renderCatalog() {
  $('cards').replaceChildren();
  $('scenario-count').textContent = state.scenarios.length + ' bounded demonstrations · synthetic data only';
  for (const s of state.scenarios) {
    const b = text('button', '', 'card' + (selected === s.id ? ' selected' : ''));
    b.setAttribute('aria-pressed', String(selected === s.id));
    b.append(text('span', s.category, 'card-label'), text('h3', s.name), text('span', s.duration, 'small'));
    b.addEventListener('click', () => { selected = s.id; runId = null; renderCatalog(); renderResult(null); });
    $('cards').append(b);
  }
  const s = state.scenarios.find(s => s.id === selected);
  $('category').textContent = s.category; $('experiment-name').textContent = s.name;
  $('description').textContent = s.description; $('scope').textContent = s.scope;
  $('effect').textContent = s.effect; $('duration').textContent = s.duration + ' · One experiment at a time';
  $('expected').replaceChildren(...s.expected.map(item => text('li', item)));
  $('run').disabled = !!state.active; $('run').textContent = state.active ? 'Experiment running…' : 'Run experiment';
}
function table(headers, rows) {
  const t = document.createElement('table'), head = document.createElement('thead'), body = document.createElement('tbody');
  const hr = document.createElement('tr'); headers.forEach(h => hr.append(text('th', h))); head.append(hr);
  rows.forEach(row => { const tr = document.createElement('tr'); row.forEach(cell => tr.append(text('td', String(cell)))); body.append(tr); });
  t.append(head, body); return t;
}
function renderResult(data) {
  $('empty-result').hidden = !!data; $('live-result').hidden = !data;
  const status = data?.run.status || 'neutral';
  $('run-status').className = 'badge ' + status;
  $('run-status').textContent = data ? status[0].toUpperCase() + status.slice(1) : 'Ready';
  if (!data) return;
  const r = data.run;
  $('run-meta').textContent = 'Started ' + date(r.started_at) + ' · Run ' + r.id.slice(0, 8);
  $('result-summary').textContent = r.status === 'running' ? 'The experiment is running. Results appear after its checks finish.' : r.status === 'passed' ? 'The checks passed within this experiment’s stated boundary.' : (r.error || 'The experiment did not pass. Review its log; do not infer protection from an incomplete result.');
  $('log').textContent = data.log || 'Waiting for output…';
  $('download').hidden = r.status === 'running'; $('download').href = '/api/runs/' + r.id + '/evidence';
  $('result-table').replaceChildren();
  const nats = data.artifacts['nats-result.json']?.data;
  if (nats) {
    $('result-table').append(table(['Transport', 'Check', 'Identity', 'Outcome'], nats.results.map(c => [c.transport.toUpperCase(), c.case, c.identity, c.outcome])));
    nats.limitations.forEach(item => $('result-table').append(text('p', item, 'muted')));
  }
  const waf = data.artifacts['waf-result.json']?.data;
  if (waf) $('result-table').append(table(['Mode', 'Probe', 'HTTP', 'Backend received'], waf.results.flatMap(m => m.cases.map(c => [m.mode, c.case, c.http_status, c.backend_received ? 'Yes' : 'No']))));
  const platform = data.artifacts['platform-result.json']?.data;
  if (platform) $('result-table').append(table(['Check', 'Observed result'], [
    ['Network allow / deny pair', platform.network_allowed_and_denied_verified ? 'Verified' : 'Not verified'],
    ['Restricted admission', platform.restricted_admission_verified ? 'Verified' : 'Not verified']
  ]));
  const workloads = (data.artifacts['workloads-result.json'] || data.artifacts['support-workloads-result.json'] || data.artifacts['database-workload-result.json'] || data.artifacts['observability-result.json'])?.data;
  if (workloads) {
    $('result-table').append(table(['Service', 'UID', 'Root filesystem', 'API token'], workloads.workloads.map(w => [w.name, w.uid, w.root_readonly ? 'Read-only' : 'Writable', w.token_absent ? 'Absent' : 'Present'])));
    $('result-table').append(table(['Unsafe variation', 'Admission'], workloads.admission_checks.map(c => [c.case, 'Denied'])));
    if (workloads.stores) $('result-table').append(table(['Store', 'Persistent volume', 'Historical cutover proof'], workloads.stores.map(s => [s.name, s.bound ? 'Bound' : 'Not bound', s.verified_files + ' files matched; ' + s.historical_check])));
    if (workloads.storage) $('result-table').append(table(['Storage check', 'Observed result'], [['Persistent volume', workloads.storage.bound ? 'Bound' : 'Not bound'], ['Historical restart recovery', workloads.storage.historical_restart_recovery_verified ? 'Verified at ' + date(workloads.storage.migration_completed_at) : 'Not verified']]));
    if (workloads.pod_admission_checks?.length) $('result-table').append(table(['Pod boundary', 'Attempt', 'Result'], workloads.pod_admission_checks.map(c => [c.workload, c.case, 'Denied'])));
  }
  const sql = data.artifacts['database-permissions-result.json']?.data;
  if (sql) {
    $('result-table').append(table(['Service', 'SQL role', 'Permissions', 'Denied operations'], sql.services.map(s => [s.service, s.role, s.table_permissions_verified + ' checked', s.denied_operations.length + ' · SQLSTATE ' + s.sqlstate])));
    $('result-table').append(table(['Service', 'Unsafe change', 'Admission'], sql.admission_checks.map(c => [c.service, c.case, 'Denied'])));
    if (sql.rotation) $('result-table').append(table(['Credential rotation', 'Observed result'], [['Service', sql.rotation.service], ['Retired password on a new connection', sql.rotation.retired_login_rechecked ? 'Rejected again in this run' : 'Historical check'], ['Old sessions after password change', sql.rotation.old_jdbc_sessions_survived_change + ' remained'], ['Old pool after Pod replacement', 'Drained; new connections verified'], ['Trading after rotation', 'Verified at ' + date(sql.rotation.completed_at)]]));
    $('result-table').append(text('p', 'Application connections using the bootstrap administrator: ' + sql.legacy_admin_jdbc_sessions + '. Service grants do not enforce account ownership.', 'muted'));
  }
  const collector = data.artifacts['collector-result.json']?.data;
  if (collector) {
    $('result-table').append(table(['Application namespace check', 'Result'], collector.application_admission.map(c => [c.case, c.denied_by])));
    $('result-table').append(table(['Collector exception check', 'Result'], collector.collector_admission.map(c => [c.case, 'Denied'])));
    $('result-table').append(table(['Evidence and limitations', 'Observed result'], [['Fresh log delivery to Loki', collector.fresh_log_delivery.received_in_loki ? 'Verified' : 'Not verified'], ['Namespace policy', collector.application_policy || 'baseline:v1.35 (historical result)'], ['Unrelated root Pod', collector.baseline_allows_root_writable_pod_dry_run ? 'Allowed in this historical Baseline run' : 'Rejected by Restricted'], ['Read-only root, resource bounds and token suppression', 'Additional named-workload policies; not guaranteed by Restricted alone'], ['Collector host-log mount', 'Read-only; root and explicit API token are documented exceptions']]));
  }
  if (r.status === 'failed' || r.status === 'inconclusive') $('logs').open = true;
}
function renderLists() {
  $('roadmap-items').replaceChildren();
  state.roadmap.forEach(item => { const row = text('div', '', 'list-row roadmap-row'), copy = document.createElement('div'); copy.append(text('h3', item.name), text('p', item.detail)); row.append(copy, text('span', item.status, 'badge ' + (item.status === 'Verified' ? 'passed' : 'neutral'))); $('roadmap-items').append(row); });
  $('run-history').replaceChildren();
  if (!state.runs.length) $('run-history').append(text('p', 'No console runs yet. Choose an experiment to create your first evidence record.', 'muted'));
  state.runs.forEach(r => { const row = text('div', '', 'list-row'), copy = document.createElement('div'); copy.append(text('h3', nameFor(r.scenario)), text('p', date(r.started_at) + ' · ' + r.id.slice(0, 8))); const button = text('button', 'View result', 'row-button'); button.addEventListener('click', async () => { selected = r.scenario; runId = r.id; renderCatalog(); switchTab('experiments'); try { renderResult(await api('/api/runs/' + runId)); } catch(e) { showError(e.message); } }); row.append(copy, text('span', r.status, 'badge ' + r.status), button); $('run-history').append(row); });
  $('historical').replaceChildren();
  state.historical.forEach(h => { const row = text('div', '', 'list-row'), copy = document.createElement('div'); copy.append(text('h3', nameFor(h.scenario)), text('p', h.scope + ' · Recorded ' + date(h.recorded_at))); row.append(copy, text('span', 'Previously verified', 'badge neutral')); $('historical').append(row); });
}
$('run').addEventListener('click', async () => {
  $('run').disabled = true; showError('');
  try { const run = await api('/api/runs', {method:'POST',headers:{'Content-Type':'application/json','X-Lab-CSRF':state.csrf},body:JSON.stringify({scenario:selected})}); runId = run.id; await refresh(); }
  catch(e) { showError(e.message); $('run').disabled = !!state?.active; }
});
let refreshing = false;
async function refresh() {
  if (refreshing) return; refreshing = true;
  try {
    const previous = state;
    state = await api('/api/state');
    $('connection').textContent = state.active ? 'Local runner · Experiment active' : 'Local runner connected';
    if (!previous) renderCatalog();
    $('run').disabled = !!state.active;
    $('run').textContent = state.active ? 'Experiment running…' : 'Run experiment';
    if (!previous || JSON.stringify(previous.runs) !== JSON.stringify(state.runs)) renderLists();
    if (runId) renderResult(await api('/api/runs/' + runId));
  }
  catch(e) { $('connection').textContent = 'Runner unavailable'; showError(e.message); $('run').disabled = true; }
  finally { refreshing = false; }
}
refresh(); setInterval(refresh, 3000);
