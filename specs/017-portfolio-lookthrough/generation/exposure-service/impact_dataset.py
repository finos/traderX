"""Analytical firm-wide impact fixture; unrelated cash, direct and shared funds."""


def generate_impact(accounts=1000, layers=2, width=3):
    if accounts < 4 or not 1 <= layers <= 4 or not 2 <= width <= 5:
        raise ValueError('Use >=4 accounts, 1..4 fund layers and width 2..5')
    nodes=[('IGROUP','Industrial Group','company',100),
           ('IOP1','Manufacturing subsidiary','company',100),
           ('IOP2','Logistics subsidiary','company',100),
           ('ICASHCO','Unrelated issuer','company',100),
           ('IS0','Manufacturing equity','security',100),
           ('IS1','Logistics equity','security',100),
           ('ICASH','Unrelated holding','security',100),
           ('IZERO','Unheld corporate group','company',100)]
    links=[('IS0','IOP1',1),('IS1','IOP2',1),('IOP1','IGROUP',1),
           ('IOP2','IGROUP',1),('ICASH','ICASHCO',1)]
    for layer in range(layers):
        for fund in range(width):
            name=f'IF{layer}_{fund}'
            nodes.append((name,f'Layer {layer+1} shared fund {fund+1}','fund',100))
            if layer==layers-1:
                links.extend([(name,'IS0',.3),(name,'IS1',.2),(name,'ICASH',.5)])
            else:
                links.extend((name,f'IF{layer+1}_{child}',1/width) for child in range(width))
    positions=[]
    expected=[]
    for index in range(accounts):
        account=70000+index
        scale=(1+index%5)*(1,10,5,1)[index%4]
        nodes.append((f'A{account}',f'Impact portfolio {index}','account',100))
        bucket=index%4
        holdings=([( 'IS0',1000)] if bucket==0 else
                  [('IF0_0',300),('IF0_1',300),('ICASH',400)] if bucket==1 else
                  [('IF0_0',300),('IS1',100),('ICASH',600)] if bucket==2 else
                  [('ICASH',1000)])
        positions.extend((account,security,quantity*scale) for security,quantity in holdings)
        fraction=(1,.3,.25,0)[bucket]
        paths=(1,4*width**(layers-1),2*width**(layers-1)+1,0)[bucket]
        expected.append({'accountId':account,'portfolioValue':100000*scale,
                         'totalFraction':fraction,'directFraction':(1,0,.1,0)[bucket],
                         'exposureValue':100000*scale*fraction,'pathCount':paths})
    return {'profile':f'impact-{accounts}-l{layers}-w{width}','seed':42,
            'asOf':'2026-11-12T00:00:00Z','nodes':nodes,'links':links,'positions':positions,
            'scenarios':[], 'impactExpected':expected, 'target':'IGROUP'}
