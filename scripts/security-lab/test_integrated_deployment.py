import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import integrated_deployment as compiler


class IntegratedDeploymentTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.root=Path(self.temp.name).resolve()
        self.source=compiler.source_manifest();self.revision='0'*40
        self.config={'schema_version':1,'namespace':'traderx-security-lab-integrated',
            'platform':'linux/amd64','source_commit':self.revision,'gateway':{'name':'security-gateway','namespace':'traderx-lab-edge'},
            'dependencies':{n:{'port':p,'transport':s,'namespace':'traderx-security-lab-integrated'} for n,(p,s) in compiler.DEPS.items()},
            'workloads':{}}
        for role in compiler.ROLES:self.config['workloads'][role]=self.make_image(role)

    def tearDown(self):self.temp.cleanup()

    def put(self,layout,value,metadata=True):
        data=compiler.encoded(value) if metadata else value
        digest=compiler.sha(data);path=layout/'blobs/sha256'/digest
        path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        return {'digest':'sha256:'+digest,'size':len(data)}

    def make_image(self,role,alter=None):
        layout=self.root/role;layout.mkdir(exist_ok=True)
        keys=['ca.pem','config.json']
        argv=['/usr/bin/java','-jar','/app/candidate.jar']
        if role in compiler.MATERIALIZED_ROLES:
            argv=['/usr/local/bin/python','/opt/traderx/private_materializer.py','--source','/run/projected','--target','/run/private/config']
            argv += [p for key in keys for p in ('--key',key)]
            argv += ['--','/usr/local/bin/python','/opt/traderx/entrypoint.py','--config','/run/private/config/config.json']
        if role in compiler.JAVA_ROLES:
            from java_runtime import role_contract
            keys=list(role_contract(role)['keys'])
            argv=['/usr/local/bin/python','/opt/traderx/private_materializer.py','--source','/run/projected','--target','/run/private/config']
            argv += [p for key in keys for p in ('--key',key)]
            argv += ['--','/usr/local/bin/python','/opt/traderx/java_runtime.py','--role',role,'--config','/run/private/config/config.json']
        if role=='people-service':
            from people_runtime import FILES
            keys=sorted(FILES)
            argv=['/usr/local/bin/python','/opt/traderx/people_runtime.py']
        labels={'org.opencontainers.image.revision':self.revision,'traderx.security-lab.role':role,
            'traderx.security-lab.source-manifest':self.source['sha256'],'traderx.security-lab.config-interface':'private-config-v1',
            'traderx.security-lab.bind-address':'0.0.0.0','traderx.security-lab.transport':'https','traderx.security-lab.port':str(compiler.ROLES[role])}
        layer=self.put(layout,b'non-executable unit-test fixture layer',False)
        layer['mediaType']='application/vnd.oci.image.layer.v1.tar'
        config={'architecture':'amd64','os':'linux','rootfs':{'type':'layers','diff_ids':[layer['digest']]},
            'config':{'User':'10001:10001','Entrypoint':argv,'Cmd':[],'Labels':labels}}
        if alter:alter(config)
        descriptor_config=self.put(layout,config);descriptor_config['mediaType']='application/vnd.oci.image.config.v1+json'
        manifest={'schemaVersion':2,'mediaType':'application/vnd.oci.image.manifest.v1+json','config':descriptor_config,'layers':[layer]}
        descriptor=self.put(layout,manifest)
        (layout/'index.json').write_bytes(compiler.encoded({'schemaVersion':2,'manifests':[descriptor]}))
        (layout/'oci-layout').write_bytes(compiler.encoded({'imageLayoutVersion':'1.0.0'}))
        return {'image':'example.invalid/test/'+role+'@'+descriptor['digest'],'oci_layout':str(layout),'secret':'private-'+role,'keys':keys}

    def compile(self):return compiler.compile_bundle(self.config)

    def test_repeatable_complete_staging_with_no_secret_values_or_auto_activation(self):
        files=self.compile();self.assertEqual(files,self.compile())
        manifest=json.loads(files['application-core.json']);plan=json.loads(files['plan.json'])
        self.assertEqual(len([d for d in manifest['items'] if d['kind']=='Deployment']),8)
        self.assertFalse(any(d['kind'] in ('Secret','Ingress','ClusterRoleBinding') for d in manifest['items']))
        for doc in manifest['items']:
            if doc['kind']=='Deployment':
                self.assertEqual(doc['spec']['replicas'],0)
                pod=doc['spec']['template']['spec'];self.assertFalse(pod['automountServiceAccountToken'])
                self.assertEqual(pod['securityContext']['runAsUser'],10001)
            if doc['kind']=='Service':self.assertEqual(doc['spec']['type'],'ClusterIP')
        self.assertEqual(len(plan['execution_migrations']),5)
        self.assertIn('runtime-acceptance-blocked',plan['status'])
        self.assertNotIn(str(self.root),files['plan.json'].decode())

    def test_refuses_missing_roles_duplicate_secrets_or_cleartext_dependencies(self):
        original=copy.deepcopy(self.config)
        del self.config['workloads']['people-service']
        with self.assertRaisesRegex(ValueError,'inventory'):self.compile()
        self.config=copy.deepcopy(original)
        self.config['workloads']['position-service']['secret']=self.config['workloads']['account-service']['secret']
        with self.assertRaisesRegex(ValueError,'unique'):self.compile()
        self.config=original;self.config['dependencies']['nats-broker']['transport']='nats'
        with self.assertRaisesRegex(ValueError,'TLS'):self.compile()

    def test_layer_tampering_and_missing_blob_fail_before_bundle_emission(self):
        entry=self.config['workloads']['position-service'];layout=Path(entry['oci_layout'])
        manifest=compiler.blob(layout,json.loads((layout/'index.json').read_text())['manifests'][0])
        layer=layout/'blobs/sha256'/manifest['layers'][0]['digest'].split(':')[1]
        raw=layer.read_bytes();layer.write_bytes(b'x'*len(raw))
        with self.assertRaisesRegex(ValueError,'digest'):self.compile()
        layer.unlink()
        with self.assertRaisesRegex(ValueError,'Missing'):self.compile()

    def test_changed_source_platform_or_anonymous_listener_is_refused(self):
        for change,expected in ((lambda c:c.update(architecture='arm64'),'platform'),
            (lambda c:c['config']['Labels'].update({'traderx.security-lab.source-manifest':'a'*64}),'source'),
            (lambda c:c['config']['Labels'].update({'traderx.security-lab.bind-address':'127.0.0.1'}),'listener'),
            (lambda c:c['config']['Labels'].update({'traderx.security-lab.transport':'http'}),'listener')):
            self.config['workloads']['position-service']=self.make_image('position-service',change)
            with self.assertRaisesRegex(ValueError,expected):self.compile()

    def test_worker_without_materializer_and_baked_credentials_are_refused(self):
        self.config['workloads']['event-publisher']=self.make_image('event-publisher',lambda c:c['config'].update(Entrypoint=['/usr/local/bin/python','worker.py']))
        with self.assertRaisesRegex(ValueError,'materializer'):self.compile()
        self.config['workloads']['event-publisher']=self.make_image('event-publisher')
        self.config['workloads']['position-service']=self.make_image('position-service',lambda c:c['config'].update(Env=['DATABASE_PASSWORD=not-a-real-secret']))
        with self.assertRaisesRegex(ValueError,'credential'):self.compile()

    def test_position_requires_exact_adapter_and_writable_private_mount(self):
        docs=json.loads(self.compile()['application-core.json'])['items']
        deployment=next(d for d in docs if d['kind']=='Deployment' and d['metadata']['name']=='position-service')
        pod=deployment['spec']['template']['spec']
        self.assertEqual(len(pod['volumes']),3)
        self.assertIn({'name':'private','mountPath':'/run/private'},pod['containers'][0]['volumeMounts'])
        self.assertEqual(pod['containers'][0]['ports'],[{'name':'https','containerPort':18090}])
        self.assertNotIn('position-service',compiler.WORKERS)
        for argv in (['/usr/bin/java','-jar','/app/application.jar'],
                     ['/usr/local/bin/python','/opt/traderx/java_runtime.py','--role','account-service']):
            self.config['workloads']['position-service']=self.make_image('position-service',lambda c:c['config'].update(Entrypoint=argv))
            with self.assertRaisesRegex(ValueError,'materializer'):self.compile()
        def change_role(config):config['config']['Entrypoint'][-3]='account-service'
        self.config['workloads']['position-service']=self.make_image('position-service',change_role)
        with self.assertRaisesRegex(ValueError,'position adapter'):self.compile()

    def test_java_roles_are_materialized_with_distinct_exact_role_contracts(self):
        from java_runtime import role_contract
        docs=json.loads(self.compile()['application-core.json'])['items']
        for role,port in (('account-service',18088),('trade-processor',18091),('order-matcher',18110)):
            deployment=next(d for d in docs if d['kind']=='Deployment' and d['metadata']['name']==role)
            pod=deployment['spec']['template']['spec']
            self.assertEqual(len(pod['volumes']),3)
            self.assertIn({'name':'private','mountPath':'/run/private'},pod['containers'][0]['volumeMounts'])
            self.assertEqual(pod['containers'][0]['ports'],[{'name':'https','containerPort':port}])
            secret=next(v['secret'] for v in pod['volumes'] if v['name']=='runtime')
            self.assertEqual([item['key'] for item in secret['items']],role_contract(role)['keys'])
            self.assertEqual('entitlements.properties' in role_contract(role)['keys'],role!='trade-processor')
            def changed_role(config):config['config']['Entrypoint'][-3]='position-service'
            self.config['workloads'][role]=self.make_image(role,changed_role)
            with self.assertRaisesRegex(ValueError,'adapter'):self.compile()
            self.config['workloads'][role]=self.make_image(role)

    def test_people_uses_internal_materialization_exact_keys_and_private_volume(self):
        from people_runtime import FILES
        documents=json.loads(self.compile()['application-core.json'])['items']
        deployment=next(d for d in documents if d['kind']=='Deployment' and d['metadata']['name']=='people-service')
        pod=deployment['spec']['template']['spec'];container=pod['containers'][0]
        command=['/usr/local/bin/python','/opt/traderx/people_runtime.py']
        self.assertEqual(container['command'],command)
        self.assertEqual(container['ports'],[{'name':'https','containerPort':18089}])
        self.assertEqual(len(pod['volumes']),3)
        self.assertIn({'name':'private','emptyDir':{'sizeLimit':'16Mi'}},pod['volumes'])
        self.assertIn({'name':'private','mountPath':'/run/private'},container['volumeMounts'])
        projected=next(v['secret'] for v in pod['volumes'] if v['name']=='runtime')
        self.assertEqual(projected['items'],[{'key':name,'path':name} for name in sorted(FILES)])
        self.assertEqual(projected['defaultMode'],0o440)
        self.assertNotIn('people-service',compiler.MATERIALIZED_ROLES)
        self.assertIn('people-service',compiler.PRIVATE_ROLES)
        policy=next(d for d in documents if d['kind']=='ValidatingAdmissionPolicy' and d['metadata']['name'].endswith('-pods'))
        checks=' '.join(v['expression'] for v in policy['spec']['validations'])
        self.assertIn('"people-service"',checks)
        self.assertIn(json.dumps(command),checks)
        for name in FILES:self.assertIn('i.key == '+json.dumps(name),checks)
        for unsafe in (["/usr/share/dotnet/dotnet","/opt/traderx/PeopleService.WebApi.dll"],
                       command+['--config','/tmp/config.json'],
                       ['/usr/local/bin/python','/opt/traderx/private_materializer.py','--source','/run/projected',
                        '--target','/run/private/config','--key','config.json','--',*command]):
            self.config['workloads']['people-service']=self.make_image('people-service',lambda c:c['config'].update(Entrypoint=unsafe))
            with self.assertRaisesRegex(ValueError,'people adapter'):self.compile()
        self.config['workloads']['people-service']=self.make_image('people-service')
        self.config['workloads']['people-service']['keys']=['ca.pem','config.json']
        with self.assertRaisesRegex(ValueError,'people adapter'):self.compile()

    def test_network_allows_only_gateway_boundary_and_explicit_dependencies(self):
        docs=json.loads(self.compile()['application-core.json'])['items']
        policies={d['metadata']['name']:d['spec'] for d in docs if d['kind']=='NetworkPolicy'}
        default=policies['integrated-default-deny']
        self.assertEqual(default['ingress'],[]);self.assertEqual(default['egress'],[])
        gateway_target=[]
        for name,spec in policies.items():
            for rule in spec['ingress']:
                for peer in rule['from']:
                    if 'namespaceSelector' in peer:gateway_target.append(name)
            self.assertNotIn('ipBlock',json.dumps(spec))
        self.assertEqual(sorted(gateway_target),['integrated-browser-session'])
        self.assertEqual(policies['integrated-event-consumer']['ingress'],[])
        self.assertEqual(policies['integrated-people-service']['ingress'],[])
        def targets(name):
            return {peer.get('podSelector',{}).get('matchLabels',{}).get('app')
                for rule in policies['integrated-'+name]['egress'] for peer in rule['to']}
        self.assertTrue({'reference-data','price-publisher'}<=targets('browser-session'))
        self.assertNotIn('people-service',targets('browser-session'))
        self.assertNotIn('people-service',targets('account-service'))
        self.assertEqual(targets('order-matcher')-{None},{'database','trade-processor','identity','nats-broker'})

    def test_admission_covers_exact_images_commands_and_private_secret_for_pods_and_deployments(self):
        docs=json.loads(self.compile()['application-core.json'])['items']
        policies=[d for d in docs if d['kind']=='ValidatingAdmissionPolicy']
        self.assertEqual(len(policies),2)
        for policy in policies:
            self.assertEqual(policy['spec']['failurePolicy'],'Fail')
            expression=' '.join(v['expression'] for v in policy['spec']['validations'])
            for role,entry in self.config['workloads'].items():
                self.assertIn(entry['image'],expression);self.assertIn(entry['secret'],expression)
            self.assertIn('automountServiceAccountToken',expression)
            self.assertIn('readOnlyRootFilesystem',expression)
            self.assertIn('ephemeralContainers',expression)

    def test_cli_recompiles_artifacts_and_refuses_overwrite_or_tampering(self):
        source=self.root/'input.json';source.write_bytes(compiler.encoded(self.config));output=self.root/'bundle'
        with patch('sys.argv',['integrated_deployment','render','--input',str(source),'--output',str(output)]):compiler.main()
        with patch('sys.argv',['integrated_deployment','render','--input',str(source),'--output',str(output)]):
            with self.assertRaises(FileExistsError):compiler.main()
        with patch('sys.argv',['integrated_deployment','verify','--input',str(source),'--output',str(output)]):compiler.main()
        (output/'application-core.json').write_text('{}')
        with patch('sys.argv',['integrated_deployment','verify','--input',str(source),'--output',str(output)]):
            with self.assertRaisesRegex(ValueError,'differs'):compiler.main()


if __name__=='__main__':unittest.main()
