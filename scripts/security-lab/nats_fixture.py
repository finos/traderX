"""Bounded NATS protocol client and reviewed synthetic broker permissions."""
import json
import socket
import ssl
import time
import websocket

IMAGE='docker.io/library/nats@sha256:5e09808726b0d7500a68b07998e14a5f6d4109956d17ac221d180bc995eef314'
ACCOUNTS=['22214','62654']
EVENTS=[f'/accounts/{a}/{kind}' for a in ACCOUNTS for kind in ['trades','positions','orders']]
PERMISSIONS={
 'browser-a':{'publish':{'deny':['>']},'subscribe':{'allow':['pricing.*']+EVENTS[:3]}},
 'browser-b':{'publish':{'deny':['>']},'subscribe':{'allow':['pricing.*']+EVENTS[3:]}},
 'pricer':{'publish':{'allow':['pricing.*']},'subscribe':{'deny':['>']}},
 'trade-api':{'publish':{'allow':['/trades']},'subscribe':{'deny':['>']}},
 'processor':{'publish':{'allow':[s for s in EVENTS if not s.endswith('/orders')]},'subscribe':{'allow':['/trades']}},
 'matcher':{'publish':{'allow':['/orders']+[s for s in EVENTS if s.endswith('/orders')]},'subscribe':{'allow':['pricing.*']}},
 'observer':{'publish':{'deny':['>']},'subscribe':{'allow':['pricing.*','/trades','/orders']+EVENTS}}}

def config(passwords):
    if set(passwords)!=set(PERMISSIONS):raise ValueError('Exact fixture identities required')
    return {'port':4222,'server_name':'traderx-security-nats-fixture','max_payload':4096,
      'tls':{'cert_file':'/lab/cert.pem','key_file':'/lab/key.pem','handshake_first':True,'timeout':3},
      'websocket':{'port':8443,'tls':{'cert_file':'/lab/cert.pem','key_file':'/lab/key.pem'},'allowed_origins':['https://localhost']},
      'authorization':{'timeout':3,'users':[{'user':name,'password':passwords[name],'permissions':permissions} for name,permissions in PERMISSIONS.items()]}}

class Client:
    def __init__(self,transport,context,cert):
        self.transport=transport;self.buffer=b'';self.messages=[];self.errors=[];self.sid=0
        if transport=='tcp':self.sock=context.wrap_socket(socket.create_connection(('127.0.0.1',18444),timeout=5),server_hostname='localhost')
        elif transport=='wss':self.sock=websocket.create_connection('wss://localhost:18445',origin='https://localhost',sslopt={'ca_certs':str(cert),'cert_reqs':ssl.CERT_REQUIRED,'check_hostname':True},timeout=5,http_no_proxy=['localhost','127.0.0.1'])
        else:raise ValueError('Unknown fixture transport')
        try:
            line=self.line();assert line.startswith(b'INFO '),'Expected broker INFO';self.info=json.loads(line[5:])
        except BaseException:self.close();raise
    def send(self,data):
        if self.transport=='tcp':self.sock.sendall(data)
        else:self.sock.send_binary(data)
    def receive(self):
        data=self.sock.recv(8192) if self.transport=='tcp' else self.sock.recv()
        if not isinstance(data,bytes) or not data:raise ConnectionError('Broker connection closed or unexpected text frame')
        self.buffer+=data
        if len(self.buffer)>65536:raise ValueError('Fixture protocol buffer exceeded')
    def line(self):
        while b'\r\n' not in self.buffer:self.receive()
        line,self.buffer=self.buffer.split(b'\r\n',1);return line
    def event(self):
        line=self.line()
        if line.startswith(b'MSG '):
            parts=line.split();size=int(parts[-1]);assert 0<=size<=4096
            while len(self.buffer)<size+2:self.receive()
            payload=self.buffer[:size];assert self.buffer[size:size+2]==b'\r\n';self.buffer=self.buffer[size+2:]
            self.messages.append({'subject':parts[1].decode(),'payload':payload.decode()});return 'message'
        if line.startswith(b'-ERR '):self.errors.append(line.decode());return 'error'
        if line==b'PING':self.send(b'PONG\r\n');return 'ping'
        if line==b'PONG':return 'pong'
        if line==b'+OK' or line.startswith(b'INFO '):return 'info'
        raise ValueError('Unexpected broker protocol response')
    def connect(self,user=None,password=None):
        value={'verbose':False,'pedantic':True,'name':'security-lab-'+(user or 'anonymous'),'lang':'python','version':'fixture-1'}
        if user is not None:value.update(user=user,**{'pass':password})
        self.send(b'CONNECT '+json.dumps(value).encode()+b'\r\n');self.flush()
        if self.errors:raise PermissionError(self.errors[-1])
    def flush(self):
        self.send(b'PING\r\n');deadline=time.monotonic()+5
        while time.monotonic()<deadline:
            if self.event()=='pong':return
        raise TimeoutError('Broker flush not confirmed')
    def subscribe(self,subject):
        self.sid+=1;self.send(f'SUB {subject} {self.sid}\r\n'.encode());self.flush()
    def publish(self,subject,payload):
        data=payload.encode();self.send(f'PUB {subject} {len(data)}\r\n'.encode()+data+b'\r\n');self.flush()
    def close(self):
        self.sock.close()
