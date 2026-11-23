import subprocess
import unittest

import lab


class ReadinessRegressionTests(unittest.TestCase):
    def run_gate(self, service_code):
        script = '''
source scripts/lib/kubernetes-smoke-readiness.sh
TRADERX_SMOKE_READY_INTERVAL=0.05
traderx_http_code_for() {
  case "$1" in
    */trade-service/health|*/trade-processor/health) echo 404 ;;
    */trade-service/actuator/health) echo "$TEST_SERVICE_CODE" ;;
    *) echo 200 ;;
  esac
}
traderx_wait_for_traderx_ingress_readiness http://fixture.invalid 0
'''
        import os
        env = dict(os.environ, TEST_SERVICE_CODE=service_code)
        return subprocess.run(['bash', '-c', script], cwd=lab.ROOT, env=env,
                              text=True, capture_output=True, timeout=5)

    def test_supported_health_routes_allow_readiness(self):
        result = self.run_gate('200')
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_unhealthy_application_still_blocks_readiness(self):
        for code in ['503', '000']:
            result = self.run_gate(code)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('not ready: trade-service', result.stdout)

    def test_collector_namespace_override_preserves_default(self):
        script = """
source scripts/lib/kubernetes-smoke-readiness.sh
kubectl() { echo "$*" >&2; if [[ "$1" == get && "$2" == deployments ]]; then return; fi; }
traderx_k8s_rollout_status_all original
"""
        import os
        for override, expected in [(None, 'original'), ('traderx-security-infra', 'traderx-security-infra')]:
            env=dict(os.environ);env.pop('TRADERX_LOG_COLLECTOR_NAMESPACE',None)
            if override: env['TRADERX_LOG_COLLECTOR_NAMESPACE']=override
            result=subprocess.run(['bash','-c',script],cwd=lab.ROOT,env=env,text=True,capture_output=True,timeout=5)
            self.assertEqual(result.returncode,0,result.stderr)
            self.assertIn('rollout status daemonset/promtail -n '+expected,result.stderr)
