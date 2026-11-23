"""Explicit allowlist for publishing private credential-rotation evidence."""
FIELDS=['phase','started_at','completed_at','old_pod_uid','new_pod_uid','old_secret_version','new_secret_version','sessions_before','sessions_after','old_fresh_login_rejected','new_login_passed','old_jdbc_sessions_survived_change','old_jdbc_sessions_drained','trading_smoke_sha256']

def public_result(state):
    if state.get('phase')!='complete':raise ValueError('Incomplete rotation cannot be published as passed')
    result={key:state[key] for key in FIELDS if key in state}
    result.update(service='position-service',role='lab_position',status='passed',limitations=['Historical rotation; console rechecks current login rejection without rotating again.','Password change alone does not terminate existing sessions.','No-surge restart can briefly interrupt position reads.'])
    return result
