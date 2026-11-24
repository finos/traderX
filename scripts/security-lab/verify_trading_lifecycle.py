"""Verify bounded synthetic trading through a temporary loopback-only port forward."""
import argparse
import json
from pathlib import Path
import re
import secrets
import selectors
import subprocess
import time
import urllib.error
import urllib.request

import credential_store
import database_lifecycle as db
from resource_operation import operation


def settled_trade_id(trades,quantity):
    matches=[t for t in trades if t.get('accountId')==22214 and t.get('security')=='IBM'
             and t.get('side')=='Buy' and t.get('quantity')==quantity and t.get('state')=='Settled']
    if len(matches)>1:raise RuntimeError('Duplicate synthetic trade outcomes')
    if not matches:return None
    trade_id=matches[0].get('id')
    if not isinstance(trade_id,str) or not re.fullmatch(r'[A-Za-z0-9-]{1,50}',trade_id):
        raise RuntimeError('Unexpected committed trade identifier')
    return trade_id


def campaign(api,credentials,port):
    db.namespace(api,db.identity(credentials))
    process=subprocess.Popen(api.command+['port-forward','-n',api.namespace,'service/edge-proxy',f'{port}:8080','--address=127.0.0.1'],stdout=subprocess.PIPE,stderr=subprocess.DEVNULL)
    base=f'http://127.0.0.1:{port}'
    def request(path,payload=None,expected=200):
        req=urllib.request.Request(base+path,data=json.dumps(payload).encode() if payload is not None else None,
                                   headers={'Content-Type':'application/json'})
        try:
            with urllib.request.urlopen(req,timeout=20) as response:status=response.status;body=response.read()
        except urllib.error.HTTPError as error:status=error.code;body=error.read()
        if status!=expected:raise RuntimeError(f'Trading HTTP check failed: {path} returned {status}')
        return json.loads(body) if body else None
    admin=credentials['bootstrap']
    def sql(text):return api.sql(admin['username'],admin['password'],text).strip()
    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout,selectors.EVENT_READ)
            if not selector.select(timeout=15) or not process.stdout.readline().startswith(b'Forwarding from 127.0.0.1:'):
                raise RuntimeError('Owned loopback port forward did not bind')
        for _ in range(40):
            if process.poll() is not None:raise RuntimeError('Owned port forward failed to start')
            try:
                request('/account-service/account/22214');break
            except (OSError,RuntimeError):time.sleep(.5)
        else:raise RuntimeError('Candidate edge did not become ready')
        for _ in range(20):
            quantity=4300+secrets.randbelow(700)
            if sql(f"SELECT count(*) FROM trades WHERE accountid=22214 AND security='IBM' AND side='Buy' AND quantity={quantity};")=='0':break
        else:raise RuntimeError('No unused synthetic trade payload found')
        result=request('/trade-service/trade/',{'security':'IBM','quantity':quantity,'accountId':22214,'side':'Buy'})
        if result.get('accountId')!=22214 or result.get('quantity')!=quantity or result.get('security')!='IBM':
            raise RuntimeError('Submission response does not match the synthetic request')
        # Pinned C3 returns a null request ID; the processor assigns the committed UUID.
        # Match an initially absent synthetic payload, then verify its committed ID in SQL.
        trade_id=None
        for _ in range(60):
            trades=request('/position-service/trades/22214')
            trade_id=settled_trade_id(trades,quantity)
            if trade_id is not None:break
            time.sleep(1)
        else:raise RuntimeError('Trade never settled in downstream read model')
        if not isinstance(trade_id,str) or not re.fullmatch(r'[A-Za-z0-9-]{1,50}',trade_id):
            raise RuntimeError('Unexpected committed trade identifier')
        if sql(f"SELECT state FROM trades WHERE id='{trade_id}';")!='Settled':raise RuntimeError('Independent SQL settlement missing')
        if sql(f"SELECT count(*) FROM trades WHERE accountid=22214 AND security='IBM' AND side='Buy' AND quantity={quantity};")!='1':
            raise RuntimeError('Synthetic trade count differs from one')
        request('/trade-service/trade/',{'security':'NO_SUCH_TICKER_123','quantity':100,'accountId':22214,'side':'Buy'},404)
        request('/trade-service/trade/',{'security':'IBM','quantity':100,'accountId':99999999,'side':'Buy'},404)
        created=request('/order-matcher/orders',{'accountId':22214,'security':'IBM','side':'Buy','quantity':77,'limitPrice':1.0},201)
        order_id=str(created.get('orderId',''))
        if not re.fullmatch(r'[A-Za-z0-9-]{1,32}',order_id):raise RuntimeError('Unexpected order identifier')
        orders=request('/order-matcher/orders?status=open&accountId=22214')
        if not any(o['orderId']==order_id for o in orders):raise RuntimeError('Created order absent from listing')
        canceled=request(f'/order-matcher/orders/{order_id}/cancel',{})
        if canceled['status']!='CANCELED' or sql(f"SELECT status FROM orderbook WHERE orderid='{order_id}';")!='CANCELED':
            raise RuntimeError('Order cancellation not confirmed independently')
        deployment=api.get('deployment','account-service',api.namespace)
        deployment.pop('status',None);deployment['metadata'].pop('managedFields',None)
        deployment['spec']['template']['spec']['containers'][0]['securityContext']['readOnlyRootFilesystem']=False
        denial=subprocess.run(api.command+['replace','--dry-run=server','-f','-'],input=json.dumps(deployment),capture_output=True,text=True,timeout=45)
        policy='traderx-lab-business-workloads-'+api.namespace.removeprefix('traderx-security-lab-')
        if denial.returncode==0 or policy not in denial.stderr:raise RuntimeError('Expected workload admission denial not observed')
        return {'status':'passed' ,'scope':'Bounded live trading candidate, not full hardened state',
            'namespace':api.namespace,'trade_id':trade_id,'order_id':order_id,
            'checks':['account read','trade submission','asynchronous settlement','independent SQL settlement',
                      'unknown ticker rejected','unknown account rejected','order creation','account order listing','cancellation with SQL outcome','unsafe workload denied by scoped admission'],
            'limitations':['Anonymous reference NATS and existing business APIs; identity/broker cutover remains pending.',
                           'Telemetry persistence, collector migration, WAF/network integration and full-state CI not covered.']}
    finally:
        process.terminate()
        try:process.wait(timeout=10)
        except subprocess.TimeoutExpired:process.kill();process.wait()
        process.stdout.close()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for arg in ('runtime-dir','store','kubeconfig','output'):parser.add_argument('--'+arg,type=Path,required=True)
    for arg in ('context','cluster-uid','namespace'):parser.add_argument('--'+arg,required=True)
    parser.add_argument('--port',type=int,default=18480)
    args=parser.parse_args()
    if args.output.exists():raise ValueError('Evidence output exists')
    with operation(args.runtime_dir,'acceptance'):
        credentials=credential_store.load(args.store)
        api=db.Kubernetes(args.kubeconfig,args.context,args.cluster_uid,args.namespace)
        result=campaign(api,credentials,args.port)
        with args.output.open('x') as target:json.dump(result,target,indent=2);target.write('\n')
    print('Trade settlement and order cancellation passed with independent SQL outcomes.')


if __name__=='__main__':main()
