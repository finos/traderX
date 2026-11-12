#!/usr/bin/env python3
"""Install portfolio capability into an inherited C2 runtime, idempotently."""
import csv
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import sys

ROOT=Path(__file__).resolve().parents[1]
sid=sys.argv[1]
number=sid[:3]
target=Path(os.environ.get('TRADERX_GENERATED_ROOT',ROOT/'generated'))/'code/target-generated'
parent=target/('order-management-matcher' if number=='017' else 'portfolio-lookthrough')
active=target/sid[4:]
if active.exists(): shutil.rmtree(active)
shutil.copytree(parent,active)
# C2's intermediate runtime packs are no longer active once copied here.
# Keep their component code, but exclude obsolete Compose/config snapshots.
for obsolete in ('observability-lgtm-compose','pricing-awareness-market-data'):
    shutil.rmtree(target/obsolete,ignore_errors=True)
service=target/'exposure-service'
shutil.copytree(ROOT/'specs/017-portfolio-lookthrough/generation/exposure-service',service,dirs_exist_ok=True,
                ignore=shutil.ignore_patterns('__pycache__'))
spec=importlib.util.spec_from_file_location('exposure_dataset',service/'dataset.py')
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
data=module.generate('demo')
manifest={'profile':'demo','seed':42,'nodes':len(data['nodes']),'referenceLinks':len(data['links']),
          'positions':len(data['positions']),'scenarios':data['scenarios']}
(service/'dataset-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
compose=(active/'docker-compose.yml').read_text()
compose=re.sub(r'^name:.*',f'name: traderx-state-{number}',compose,count=1,flags=re.M)
compose=compose.replace('postgres_state_009_data','postgres_state_'+number+'_data').replace('postgres_state_017_data','postgres_state_'+number+'_data')
# Parent 017 already has the service; replace exactly that owned block.
compose=re.sub(r'^  exposure-service:\n.*?(?=^  [a-zA-Z0-9_-]+:|^volumes:|\Z)','',compose,flags=re.M|re.S)
backend='postgres' if number=='017' else 'falkor'
addition=f'''  exposure-service:
    build:
      context: ../exposure-service
      dockerfile: Dockerfile
    environment:
      DATABASE_URL: postgresql://traderx:traderx@database:5432/traderx
      EXPOSURE_PROFILE: "${{EXPOSURE_PROFILE:-demo}}"
      EXPOSURE_BACKEND: {backend}
      REDIS_URL: redis://falkordb:6379
    ports:
      - "127.0.0.1:18120:18120"
    restart: on-failure
    depends_on:
      database:
        condition: service_healthy
'''
if number=='018':
    addition+='''      falkordb:
        condition: service_healthy

  falkordb:
    image: falkordb/falkordb:v4.16.0@sha256:f8a0e805259cf6887445d8c2cb55da722219cc3cd3202cbb4c49115fc71e144b
    command: ["redis-server", "--loadmodule", "/FalkorDB/bin/falkordb.so", "--appendonly", "yes"]
    volumes:
      - exposure_graph_data:/data
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 3s
      timeout: 3s
      retries: 30
'''
compose=compose.replace('\nvolumes:', '\n'+addition+'\nvolumes:',1)
if number=='018': compose+='  exposure_graph_data:\n'
# Seeded instrument universe participates in reference lookup and price bootstrap.
synthetic=[(i,n) for i,n,k,_ in data['nodes'] if k in ('fund','security')]
core='AAPL,MSFT,AMZN,GOOGL,META,NVDA,TSLA,IBM,BAC,C,JPM,GS,MS,UBS,DB,COF,DFS,FNMA,FIS,FNF'
tickers=core+','+','.join(i for i,_ in synthetic)
compose=re.sub(r'(REFERENCE_DATA_SUPPORTED_TICKERS|PRICE_TICKERS): "[^"\n]*"',lambda m:m[1]+': "'+tickers+'"',compose)
(active/'docker-compose.yml').write_text(compose)
reference=target/'reference-data/data/s-and-p-500-companies.csv'
with reference.open(newline='') as f: rows=list(csv.reader(f))
seen={row[0] for row in rows[1:]}
with reference.open('a',newline='') as f:
    writer=csv.writer(f)
    for ticker,name in synthetic:
        if ticker not in seen: writer.writerow([ticker,name]+['']*(len(rows[0])-2))
prices=target/'price-publisher/data/snapshot-prices.json'
quotes=json.loads(prices.read_text())
quotes.update({ticker:{'openPrice':100,'closePrice':100} for ticker,_ in synthetic})
prices.write_text(json.dumps(quotes,indent=2)+'\n')
ingress=target/'ingress/nginx.traderx.conf.template'
text=ingress.read_text()
if 'location /exposure/' not in text:
    text=text.replace('    location /reference-data/', '''    location = /exposure { return 302 /exposure/; }
    location /exposure/ {
        proxy_pass http://exposure-service:18120/;
    }

    location /reference-data/''',1)
ingress.write_text(text)
header=target/'web-front-end/angular/main/app/header/header.component.html'
text=header.read_text()
if 'href="/exposure/"' not in text:
    text=text.replace('</nav>','<a class="nav-link" href="/exposure/">Portfolio Exposure</a>\n</nav>',1)
header.write_text(text)
prometheus=active/'observability/prometheus/prometheus.yml'
text=prometheus.read_text()
if 'job_name: exposure-service' not in text:
    text+='\n  - job_name: exposure-service\n    static_configs:\n      - targets: ["exposure-service:18120"]\n'
prometheus.write_text(text)
# Containers use non-root service users. Generated configuration may originate
# from mktemp (0600); make only these public runtime assets readable in mounts.
for base in (active,service,target/'ingress',target/'postgres-database-replacement/postgres-init'):
    for path in [base,*base.rglob('*')]:
        if path.is_symlink(): continue
        path.chmod(0o755 if path.is_dir() or path.stat().st_mode & 0o111 else 0o644)
print('[ok] rendered',sid,manifest)
