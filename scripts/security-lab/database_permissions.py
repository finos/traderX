"""Reviewed SQL grants and credential references for four C3 consumers."""
import copy
import json
import re
import workloads
import support_workloads
import database_workload
NS=workloads.NS
POLICY='traderx-lab-sql-identities'
GRANTS={
 'account-service':{'role':'lab_account','tables':{'accounts':['SELECT','INSERT','UPDATE'],'accountusers':['SELECT','INSERT']},'sequences':['accounts_seq']},
 'position-service':{'role':'lab_position','tables':{'positions':['SELECT'],'trades':['SELECT']},'sequences':[]},
 'trade-processor':{'role':'lab_trade_processor','tables':{'trades':['SELECT','INSERT','UPDATE'],'positions':['SELECT','INSERT','UPDATE']},'sequences':[]},
 'order-matcher':{'role':'lab_order_matcher','tables':{'orderbook':['SELECT','INSERT','UPDATE']},'sequences':[]}}
NAMES=list(GRANTS)

def secret_name(name):return 'lab-sql-'+name

def transform(rendered):
    result=copy.deepcopy(rendered)
    for d in result['items']:
        if d['kind']!='Deployment' or d['metadata']['name'] not in GRANTS:continue
        name=d['metadata']['name'];c=d['spec']['template']['spec']['containers'][0]
        for variable,key in [('DATABASE_DBUSER','username'),('DATABASE_DBPASS','password')]:
            assert len([e for e in c['env'] if e['name']==variable])==1
            c['env']=[{'name':variable,'valueFrom':{'secretKeyRef':{'name':secret_name(name),'key':key}}} if e['name']==variable else e for e in c['env']]
        if name=='order-matcher':
            c['env']=[e for e in c['env'] if e['name']!='SPRING_JPA_HIBERNATE_DDL_AUTO']+[{'name':'SPRING_JPA_HIBERNATE_DDL_AUTO','value':'none'}]
    return result

def deployments(reference):
    return [d for d in transform(workloads.render(reference))['items'] if d['kind']=='Deployment' and d['metadata']['name'] in NAMES]

def bootstrap_deployment(reference):
    d=next(x for x in database_workload.render(reference)['items'] if x['kind']=='Deployment')
    c=d['spec']['template']['spec']['containers'][0]
    c['env']=[{'name':'POSTGRES_PASSWORD','valueFrom':{'secretKeyRef':{'name':'lab-sql-bootstrap','key':'password'}}} if e['name']=='POSTGRES_PASSWORD' else e for e in c['env']]
    return d

def admission(reference):
    p='object.spec.template.spec';c=p+'.containers[0]'
    checks=[{'expression':f'{p}.containers.size() == 1 && !has({c}.envFrom) && !has({c}.command) && !has({c}.args)','message':'SQL: reviewed entrypoint and explicit environment required'}]
    for d in deployments(reference)+[bootstrap_deployment(reference)]:
        name=d['metadata']['name'];env=d['spec']['template']['spec']['containers'][0]['env']
        terms=[f'has({c}.env)',f'{c}.env.size() == {len(env)}']
        for i,e in enumerate(env):
            v=f'{c}.env[{i}]';terms.append(f'{v}.name == '+json.dumps(e['name']))
            if 'value' in e:terms += [f'has({v}.value)',f'{v}.value == '+json.dumps(e['value']),f'!has({v}.valueFrom)']
            else:
                ref=e['valueFrom']['secretKeyRef'];terms += [f'!has({v}.value)',f'has({v}.valueFrom)',f'has({v}.valueFrom.secretKeyRef)',f'{v}.valueFrom.secretKeyRef.name == '+json.dumps(ref['name']),f'{v}.valueFrom.secretKeyRef.key == '+json.dumps(ref['key']),f'(!has({v}.valueFrom.secretKeyRef.optional) || !{v}.valueFrom.secretKeyRef.optional)']
        checks.append({'expression':f'object.metadata.name != "{name}" || ('+' && '.join(terms)+')','message':'SQL: dedicated Secret references and reviewed configuration for '+name})
    docs=copy.deepcopy(workloads.admission());docs[0]['metadata']['name']=POLICY;docs[1]['metadata']['name']=POLICY;docs[1]['spec']['policyName']=POLICY
    docs[0]['spec']['matchConditions'][0]['expression']=f'object.metadata.namespace == "{NS}" && object.metadata.name in {json.dumps(NAMES+['database'])}'
    docs[0]['spec']['validations']=checks
    return docs+support_workloads.pod_admission(docs,NAMES+['database'])

def grant_sql(credentials):
    sql=['BEGIN;','REVOKE ALL ON DATABASE traderx FROM PUBLIC;','REVOKE ALL ON SCHEMA public FROM PUBLIC;','REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;','REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;']
    for name,grant in GRANTS.items():
        role=grant['role'];password=credentials[name]['password']
        if credentials[name]['username']!=role or not re.fullmatch('[0-9a-f]{48}',password):raise ValueError('Unreviewed credentials')
        sql += [f"DO $$ BEGIN IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='{role}') THEN CREATE ROLE {role}; END IF; END $$;",f"ALTER ROLE {role} LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD '{password}';",f'REVOKE ALL ON ALL TABLES IN SCHEMA public FROM {role};',f'REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM {role};',f'REVOKE ALL ON DATABASE traderx FROM {role};',f'REVOKE ALL ON SCHEMA public FROM {role};',f'GRANT CONNECT ON DATABASE traderx TO {role};',f'GRANT USAGE ON SCHEMA public TO {role};']
        for table,verbs in grant['tables'].items():sql.append(f'GRANT {", ".join(verbs)} ON TABLE public.{table} TO {role};')
        for sequence in grant['sequences']:sql.append(f'GRANT USAGE ON SEQUENCE public.{sequence} TO {role};')
    sql.append('COMMIT;');return '\n'.join(sql)+'\n'
