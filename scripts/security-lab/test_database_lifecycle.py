import copy
import unittest
from unittest.mock import Mock, patch

import bootstrap_database
import credential_store
import database_lifecycle as lifecycle


class LifecycleTests(unittest.TestCase):
    def setUp(self):
        self.credentials={'bootstrap':{'username':'traderx','password':'a'*64},
            'runtime':bootstrap_database.credentials(),'contract':credential_store.contract()}
        self.reference=bootstrap_database.pinned_reference()

    def api(self):
        api=Mock()
        api.run.return_value='{"items":[]}'
        docs={('namespace',lifecycle.NS):{'metadata':{'uid':'ns1','labels':{lifecycle.OWNER:lifecycle.identity(self.credentials)}}}}
        for doc in lifecycle.resources(self.reference,self.credentials):
            doc['metadata'].update(uid='uid-'+doc['metadata']['name'],resourceVersion='1')
            docs[(doc['kind'].lower(),doc['metadata']['name'])]=doc
        api.get.side_effect=lambda kind,name,namespace=None:copy.deepcopy(docs.get((kind.lower(),name)))
        return api,docs

    def test_private_secrets_and_stopped_deployment(self):
        docs=lifecycle.resources(self.reference,self.credentials)
        secrets=[d for d in docs if d['kind']=='Secret']
        self.assertEqual(5,len(secrets))
        self.assertTrue(all(d['immutable'] for d in secrets))
        deployment=next(d for d in docs if d['kind']=='Deployment')
        self.assertEqual(0,deployment['spec']['replicas'])
        self.assertFalse(deployment['spec']['template']['spec']['automountServiceAccountToken'])

    def test_start_reuses_resources_before_initialize(self):
        api,_=self.api()
        with patch.object(lifecycle,'initialize',return_value='resumed') as initialize:
            self.assertEqual('resumed',lifecycle.start(api,self.reference,self.credentials))
        api.create.assert_not_called()
        initialize.assert_called_once()

    def test_foreign_namespace_no_mutations(self):
        api,docs=self.api();docs[('namespace',lifecycle.NS)]['metadata']['labels']={}
        with self.assertRaises(ValueError):lifecycle.start(api,self.reference,self.credentials)
        api.create.assert_not_called();api.run.assert_not_called()

    def test_changed_secret_no_mutations(self):
        api,docs=self.api();docs[('secret','lab-sql-bootstrap')]['data']['password']='different'
        with self.assertRaises(ValueError):lifecycle.start(api,self.reference,self.credentials)
        api.create.assert_not_called();api.run.assert_not_called()

    def test_drifted_workload_no_mutations(self):
        api,docs=self.api();docs[('deployment','database')]['spec']['template']['spec']['containers'].append({'name':'extra'})
        with self.assertRaises(ValueError):lifecycle.start(api,self.reference,self.credentials)
        api.create.assert_not_called();api.run.assert_not_called()

    def test_stop_preserves_data_and_checks_uid(self):
        api,_=self.api()
        self.assertEqual('stopped-data-retained',lifecycle.stop(api,self.credentials))
        commands=[call.args[0] for call in api.run.call_args_list]
        self.assertEqual('patch',commands[0][0]);self.assertIn('/metadata/uid',commands[0][-1])
        self.assertNotIn('delete',[command[0] for command in commands])
        api.create.assert_not_called()

    def test_stop_refuses_unowned_deployment(self):
        api,docs=self.api();docs[('deployment','database')]['metadata']['labels']={}
        with self.assertRaises(ValueError):lifecycle.stop(api,self.credentials)
        api.run.assert_not_called()

    def test_fresh_transaction_contains_marker(self):
        sql=Mock(side_effect=['','']+[v['username'] for v in self.credentials['runtime'].values()])
        self.assertEqual('initialized',lifecycle.initialize(sql,self.reference,self.credentials))
        transaction=sql.call_args_list[1].args[2]
        self.assertLess(transaction.index('CREATE TABLE lab_lifecycle.bootstrap'),transaction.index('COMMIT;'))
        self.assertIn('SET log_min_error_statement=panic',transaction)

    def test_resume_never_reseeds(self):
        sql=Mock(side_effect=['lab_lifecycle.bootstrap',lifecycle.binding(self.reference,self.credentials)]+[v['username'] for v in self.credentials['runtime'].values()])
        self.assertEqual('resumed',lifecycle.initialize(sql,self.reference,self.credentials))
        self.assertTrue(all('INSERT' not in call.args[2] for call in sql.call_args_list))

    def test_marker_mismatch_refuses(self):
        sql=Mock(side_effect=['lab_lifecycle.bootstrap','wrong'])
        with self.assertRaises(ValueError):lifecycle.initialize(sql,self.reference,self.credentials)
        self.assertEqual(2,sql.call_count)

    def test_missing_pvc_is_not_silently_recreated(self):
        api,docs=self.api()
        key=next(key for key in docs if key[0]=='persistentvolumeclaim')
        del docs[key]
        with self.assertRaises(ValueError):lifecycle.start(api,self.reference,self.credentials)
        api.create.assert_not_called();api.run.assert_not_called()

    def test_failed_sql_scales_database_back_down(self):
        api,_=self.api()
        with patch.object(lifecycle,'initialize',side_effect=ValueError('mismatch')):
            with self.assertRaises(ValueError):lifecycle.start(api,self.reference,self.credentials)
        patches=[call.args[0][-1] for call in api.run.call_args_list if call.args[0][0]=='patch']
        self.assertIn('"value": 0',patches[-1])

    def test_cluster_mismatch(self):
        api=lifecycle.Kubernetes('/unused','explicit','expected')
        with patch.object(api,'get',return_value={'metadata':{'uid':'other'}}):
            with self.assertRaises(ValueError):api.check_cluster()


if __name__=='__main__':unittest.main()
