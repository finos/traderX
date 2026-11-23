#!/usr/bin/env python3
"""Generate the lab's learning progression from canonical checkpoint definitions."""
import argparse
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
PROFILE=ROOT/'specs/012-platform-convergence-c3/security-lab'

def render(model):
    nodes=model['checkpoints'];ids={n['id'] for n in nodes}
    if len(ids)!=len(nodes):raise ValueError('Duplicate checkpoint')
    statuses={'verified','fixture','next','planned'}
    for node in nodes:
        if node['status'] not in statuses:raise ValueError('Unknown checkpoint status')
        if node['status'] in ['verified','fixture'] and not node.get('evidence'):raise ValueError('Verified checkpoint requires evidence')
    outgoing={key:[] for key in ids}
    for edge in model['edges']:
        if edge['from'] not in ids or edge['to'] not in ids:raise ValueError('Unknown edge endpoint')
        outgoing[edge['from']].append(edge['to'])
    visiting=set();done=set()
    def visit(key):
        if key in visiting:raise ValueError('Cyclic learning progression')
        if key in done:return
        visiting.add(key)
        for target in outgoing[key]:visit(target)
        visiting.remove(key);done.add(key)
    for key in ids:visit(key)
    lines=['# Security Lab learning progression','','This is the checkpoint roadmap for planned State 019, currently implemented as an experimental C3 profile. Checkpoints are not separate numbered states. Connections show learning dependencies, not generation parents; State 019 has C3 as its parent. Status reflects recorded checkpoint evidence, not a live health monitor.','','Generated from `progression.json` with `scripts/security-lab/render_progression.py`; update those inputs, not this page.','','```mermaid','flowchart TB','  C3["012 / C3 platform checkpoint"]','  subgraph LAB["Security Lab — staged learning profile"]']
    for node in nodes:
        lines.append('    '+node['id']+'['+json.dumps(node['title']+' — '+node['label'],ensure_ascii=False)+']')
    lines+=['  end','  C3 --> baseline']
    for edge in model['edges']:
        if edge['from'] not in ids or edge['to'] not in ids:raise ValueError('Unknown edge endpoint')
        lines.append('  '+edge['from']+(' -.-> ' if edge.get('optional') else ' --> ')+edge['to'])
    lines+=['  calm["Separate CALM follow-on state — planned; number undecided"]','  learning --> calm','  classDef verified fill:#d7f5dd,stroke:#2e7d32,color:#16351b','  classDef fixture fill:#e5f0ff,stroke:#2864b4,color:#102b4a','  classDef next fill:#fff0cf,stroke:#966400,color:#493200,stroke-width:3px','  classDef planned fill:#f2f3f5,stroke:#697386,color:#253047,stroke-dasharray:5 4']
    for status in sorted(statuses):
        names=[n['id'] for n in nodes if n['status']==status]
        if status=='planned':names.append('calm')
        if names:lines.append('  class '+','.join(names)+' '+status)
    lines+=['```','','**Legend:** green = verified within the stated scope; blue = isolated fixture only; amber = next implementation checkpoint; grey/dashed = planned. Text labels carry status as well as color. Dashed arrows are optional learning branches.','','## Checkpoint questions and proof','','| Checkpoint | Learner question | Acceptance evidence |','| --- | --- | --- |']
    for node in nodes:
        refs='; '.join('['+Path(p).name+']('+p+')' for p in node.get('evidence',[])) or 'Planned; no result claimed'
        lines.append('| '+node['title']+' | '+node['question']+' | '+refs+' |')
    lines+=['','## How to explore each phase','','Predict an outcome, run the positive and negative checks, inspect the decision and resulting state, reset the synthetic data, then explain one remaining limitation. Advancement requires the checkpoint evidence; a green fixture does not mean the corresponding live C3 control is enabled.','','The current console exposes individual experiments. A phase navigator, reproducible checkpoint switching and guided assessments remain planned; this diagram is not an implementation of those features.','','Residual-risk exercises follow [the experiment contract](contracts/residual-risk.md). A successful assumed-compromise action is not proof of a real external exploit. Known-CVE reproduction has a separate verified-vulnerability gate. The CALM follow-on keeps the same tests and compares manual configuration with supported model-derived controls.','']
    return '\n'.join(lines)

def main():
    p=argparse.ArgumentParser();p.add_argument('--check',action='store_true');a=p.parse_args()
    model=json.loads((PROFILE/'progression.json').read_text());content=render(model);target=PROFILE/'progression.md'
    for node in model['checkpoints']:
        for ref in node.get('evidence',[]):
            if not (PROFILE/ref).is_file():raise ValueError('Missing checkpoint evidence: '+ref)
    if a.check:
        if not target.exists() or target.read_text()!=content:raise SystemExit('Progression diagram is stale')
    else:target.write_text(content)
    print('Security Lab progression verified.' if a.check else 'Security Lab progression generated.')

if __name__=='__main__':main()
