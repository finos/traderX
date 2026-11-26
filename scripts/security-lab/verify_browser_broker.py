"""Real TLS broker -> account-scoped hub -> Keycloak browser cookie campaign."""
import argparse
import asyncio
import json
import os
from pathlib import Path
import ssl
import tempfile
import time
import urllib.parse
import uuid

from browser_broker import BrokerEvents, MAX_EVENTS, reader_permissions
from browser_session import BrowserServer, ORIGIN, SESSION
from event_delivery import connect_broker, validate_event
from jetstream_fixture import broker
from resource_operation import operation
from verify_browser_api import Browser, provider


def envelope(account, sequence=1):
    execution=str(uuid.uuid4())
    return {'executionId':execution,'eventId':execution+':trade','eventKind':'trade.settled',
        'eventSequence':sequence,'payload':{'accountId':account,'price':99999,'quantity':99999}}


def wait_for(predicate, label, seconds=10):
    deadline=time.monotonic()+seconds
    while time.monotonic()<deadline:
        value=predicate()
        if value:return value
        time.sleep(.05)
    raise AssertionError(label)


def campaign(runtime):
    if not __debug__:raise RuntimeError('Browser broker campaign requires assertions')
    checks=[]
    def check(name,value):
        if not value:raise AssertionError(name)
        checks.append(name);print(name+': passed',flush=True)
    with tempfile.TemporaryDirectory(prefix='browser-broker-',dir=runtime) as temp:
        private=Path(temp)
        with provider(runtime,private) as (mount,context,jwks,passwords):
            extra={f'browser-{account}':reader_permissions(account) for account in (22214,62654)}
            with broker(runtime,extra_permissions=extra) as fixture:
                async def connect(user,errors=None,password=None,ca=None):
                    return await connect_broker(fixture['endpoint'],user,password or fixture['passwords'][user],ca or fixture['ca'],errors)
                async def publish(values):
                    client=await connect('publisher')
                    try:
                        for index,(account,value) in enumerate(values):
                            topic=f'/accounts/{account}/trades'
                            await client.publish(topic, value if isinstance(value,bytes) else validate_event(topic,value))
                            if index % 8 == 7:await asyncio.sleep(.02)
                        await client.flush(timeout=3)
                    finally:await client.close()
                async def denied_broker_operations():
                    from nats.errors import Error as NatsError
                    try:await connect('browser-22214',password='incorrect-secret')
                    except NatsError:checks.append('actual broker rejects wrong reader credential')
                    else:raise AssertionError('Wrong reader credential accepted')
                    try:await connect('browser-22214',ca=mount/'cert.pem')
                    except ssl.SSLCertVerificationError:checks.append('reader rejects untrusted broker TLS')
                    else:raise AssertionError('Untrusted broker certificate accepted')
                    errors=[];received=[];client=await connect('browser-22214',errors)
                    try:
                        async def rejected(action,label):
                            count=len(errors);await action();await client.flush(timeout=3)
                            deadline=asyncio.get_running_loop().time()+2
                            while len(errors)==count and asyncio.get_running_loop().time()<deadline:await asyncio.sleep(.02)
                            check(label,len(errors)>count)
                        async def foreign_subscription():
                            async def discard(message):received.append(message.subject)
                            await client.subscribe('/accounts/62654/trades',cb=discard)
                        await rejected(foreign_subscription,'actual broker denies another account subscription')
                        await publish([(62654,envelope(62654))]);await asyncio.sleep(.1)
                        check('denied cross-account subscription receives no message',not received)
                        await rejected(lambda:client.publish('/accounts/22214/trades',validate_event('/accounts/22214/trades',envelope(22214))),
                            'actual broker denies publication by readonly reader')
                        await rejected(lambda:client.publish('$JS.API.STREAM.DELETE.SECURITY_EVENTS',b'{}'),
                            'actual broker denies reader management operation')
                    finally:await client.close()
                asyncio.run(denied_broker_operations())
                identities={account:{'user':f'browser-{account}','password':fixture['passwords'][f'browser-{account}']} for account in (22214,62654)}
                hub=BrokerEvents({'lab-reader':{22214},'lab-trader':{62654},'lab-operator':set()},identities,fixture['endpoint'],fixture['ca']).start()
                server=None
                try:
                    wait_for(hub.ready,'Scoped broker subscriptions did not become ready')
                    server=BrowserServer(mount/'cert.pem',mount/'key.pem',context,jwks,broker_events=hub).start()
                    browser=Browser(context)
                    def call(path,body=None,headers=None):return browser.request(ORIGIN+path,body,headers)
                    def poll(cursor=None):
                        status,_,body=call('/events'+('?' + urllib.parse.urlencode({'after':cursor}) if cursor else ''))
                        return status,json.loads(body)
                    check('anonymous notification poll denied',poll()[0]==401)
                    browser.login('reader',passwords['reader'])
                    status,initial=poll();check('real reader login obtains initial snapshot reset',status==200 and initial['reset'] and not initial['events'])
                    check('caller account selection rejected',call('/events?accountId=62654')[0]==400)
                    check('duplicate cursor rejected',call('/events?after=x&after=y')[0]==400)
                    check('malformed cursor rejected',call('/events?after=incorrect')[0]==400)
                    check('browser notification publish route unavailable',call('/events',b'{}',{'Origin':ORIGIN})[0]==405)
                    asyncio.run(publish([(62654,envelope(62654)),(22214,envelope(22214))]))
                    def delivered():
                        status,value=poll(initial['cursor'])
                        return value if status==200 and value.get('events') else None
                    page=wait_for(delivered,'Browser did not receive own-account notification')
                    check('reader receives own-account notification only',len(page['events'])==1 and page['events'][0]['accountId']==22214)
                    text=json.dumps(page)
                    check('notification contains no business payload or broker credentials','payload' not in text and '99999' not in text and all(secret not in text for secret in fixture['passwords'].values()))
                    cursor=page['cursor']
                    asyncio.run(publish([(22214,b'{}'),(22214,json.dumps(envelope(62654)).encode())]))
                    time.sleep(.2)
                    status,invalid=poll(cursor)
                    check('malformed and wrong-account wire envelopes discarded',status==200 and not invalid['events'] and invalid['cursor']==cursor)
                    # Observe an actual broker restart, not merely a synthetic status flag.
                    check('broker restart retains its explicit loopback endpoint',fixture['restart']()==fixture['endpoint'])
                    def reconnected():
                        status,value=poll(cursor)
                        return value if status==200 and value.get('reset') and value['cursor']!=cursor else None
                    try:page=wait_for(reconnected,'Broker reconnect did not invalidate stale snapshot',seconds=15)
                    except AssertionError:
                        raise AssertionError('Broker reconnect unavailable: '+json.dumps(hub.diagnostics(),sort_keys=True)) from None
                    check('real broker restart requires fresh HTTP snapshot',page['reset'] and not page['events'])
                    cursor=page['cursor']
                    asyncio.run(publish([(22214,envelope(22214,index+1)) for index in range(MAX_EVENTS+1)]))
                    wait_for(lambda:hub.cache['lab-reader']['seq']>=MAX_EVENTS+1,'Burst was not observed by the bounded cache')
                    def overrun():
                        status,value=poll(cursor)
                        return value if status==200 and value.get('reset') else None
                    page=wait_for(overrun,'Overflow did not require snapshot reset')
                    check('bounded cache overflow returns reset instead of partial history',page['reset'] and not page['events'])
                    _,_,raw=call('/session');session=json.loads(raw)
                    old=next(cookie.value for cookie in browser.jar if cookie.name==SESSION)
                    check('logout ends notification access',call('/logout',b'',{'Origin':ORIGIN,'X-CSRF-Token':session['csrf']})[0]==200 and poll()[0]==401)
                    check('retired notification cookie cannot be replayed',call('/events',headers={'Cookie':SESSION+'='+old})[0]==401)
                    browser.login('trader',passwords['trader']);status,initial=poll()
                    check('second real identity obtains independent cache epoch',status==200 and initial['cursor'].split(':')[0]!=cursor.split(':')[0])
                    hub.replace_grants('lab-trader',{22214})
                    check('policy revision change retires existing browser session',poll(initial['cursor'])[0]==403 and call('/session')[0]==401)
                    hub.replace_grants('lab-trader',{62654})
                    browser.login('trader',passwords['trader']);poll();hub.revoke('lab-trader')
                    check('server-owned broker grant revocation retires cookie session',poll()[0]==403 and call('/session')[0]==401)
                    browser.login('reader',passwords['reader']);poll()
                    with server.store.lock:
                        for session in server.store.sessions.values():session['until']=0
                    check('expired session cannot poll broker notifications',poll()[0]==401)
                    browser.login('operator',passwords['operator']);status,page=poll()
                    check('operator role alone receives no account events',status==200 and page['events']==[])
                    check('notification response schema remains bounded',set(page)=={'cursor','reset','events'})
                finally:
                    if server is not None:server.close()
                    hub.close()
                check('scoped broker subscriber threads stop cleanly',not hub.thread.is_alive())
                image=fixture['image']
    return {'status':'passed','scope':'Real broker mediation and Keycloak cookie fixture; not deployed full browser trading',
        'broker_image':image,'checks':checks,'limitations':[
            'Broker policies and session revocation do not establish dynamic authorization reload in all owning APIs.',
            'The feed is a bounded invalidation cache; HTTP snapshots are authoritative and broker reconnect forces reset.',
            'Market/order payloads, browser-rendered trading, deployment credential rotation and gateway rollout remain separate gates.',
            'No business database is part of this campaign; settlement/database evidence is recorded by the trading/delivery campaigns.']}


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-dir',required=True,type=Path);parser.add_argument('--output',required=True,type=Path)
    args=parser.parse_args();os.umask(0o077)
    if args.output.exists():raise ValueError('Evidence already exists')
    with operation(args.runtime_dir,'fixture'):result=campaign(args.runtime_dir)
    with args.output.open('x') as output:json.dump(result,output,indent=2);output.write('\n')
    print(json.dumps(result,sort_keys=True))


if __name__=='__main__':main()
