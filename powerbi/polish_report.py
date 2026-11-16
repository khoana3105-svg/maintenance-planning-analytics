"""Revise working PBIR visuals in place; keep their query bindings."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parent
PAGES=ROOT/'Maintenance.Report/definition/pages'
def write(p,obj):p.write_text(json.dumps(obj,indent=2,ensure_ascii=False),encoding='utf-8')
def lit(value):return {'expr':{'Literal':{'Value':str(value)}}}
def color(value):return {'solid':{'color':lit("'"+value+"'")}}
def textbox(page,name,text,x,y,width,height,size=16,bold=False):
    target=page/'visuals'/name/'visual.json';target.parent.mkdir(parents=True,exist_ok=True)
    write(target,{'$schema':'https://developer.microsoft.com/json-schemas/fabric/item/report/definition/visualContainer/2.1.0/schema.json',
        'name':name,'position':{'x':x,'y':y,'z':1,'height':height,'width':width,'tabOrder':0},
        'visual':{'visualType':'textbox','objects':{'general':[{'properties':{'paragraphs':[{'textRuns':[{'value':text,'textStyle':{'fontFamily':'Segoe UI','fontSize':f'{size}pt','fontWeight':'bold' if bold else 'normal','color':'#19324D'}}]}]}}]},'drillFilterOtherVisuals':True}})

for page in PAGES.iterdir():
    if not page.is_dir():continue
    metadata=json.loads((page/'page.json').read_text(encoding='utf-8'))
    titles={'overview':'Maintenance overview','reliability':'Machine reliability & failure analysis','pm':'Preventive maintenance performance'}
    metadata['displayName']=titles[page.name]
    metadata['objects']={'background':[{'properties':{'color':color('#F3F6FA'),'transparency':lit('0D')}}]}
    write(page/'page.json',metadata)
    for p in (page/'visuals').glob('*/visual.json'):
        obj=json.loads(p.read_text(encoding='utf-8'));v=obj.get('visual',{});kind=v.get('visualType');name=obj['name']
        if kind=='textbox':continue
        pos=obj['position']
        if name.startswith('slicer'):pos['y']=95;pos['height']=85
        elif name.startswith('card'):pos['y']=195;pos['height']=115
        elif name.startswith('chart'):pos['y']=330;pos['height']=285
        elif name in ['tasks','failures','machinebreakdowns']:pos['y']=620;pos['height']=245
        container=v.setdefault('visualContainerObjects',{})
        container.setdefault('title',[{'properties':{}}])[0]['properties'].update({'fontColor':color('#19324D'),'fontSize':lit('14D'),'bold':lit('true')})
        if kind=='card':
            measure=v['query']['queryState']['Values']['projections'][0]['field']['Measure']['Property']
            caption={'MTTR':'MTTR (hours / repair)','MTBF':'MTBF (estimated hours / failure)'}.get(measure,measure)
            container['title'][0]['properties']['text']=lit("'"+caption+"'")
        container['background']=[{'properties':{'show':lit('true'),'color':color('#FFFFFF'),'transparency':lit('0D')}}]
        container['border']=[{'properties':{'show':lit('true'),'color':color('#D9E2EC'),'radius':lit('6D')}}]
        objects=v.setdefault('objects',{})
        if kind=='card':
            objects['labels']=[{'properties':{'fontSize':lit('30D'),'color':color('#123B5D'),'labelDisplayUnits':lit('0D')}}]
            objects['categoryLabels']=[{'properties':{'show':lit('false')}}]
        elif kind in ['clusteredBarChart','lineChart']:
            objects['dataPoint']=[{'properties':{'defaultColor':color('#167D9A')}}]
            objects['categoryAxis']=[{'properties':{'fontSize':lit('12D'),'labelColor':color('#334E68')}}]
            objects['valueAxis']=[{'properties':{'fontSize':lit('12D'),'labelColor':color('#334E68'),'start':lit('0D')}}]
            if page.name=='pm':objects['valueAxis'][0]['properties']['end']=lit('1D')
            if kind=='clusteredBarChart':objects['labels']=[{'properties':{'show':lit('true'),'fontSize':lit('11D'),'color':color('#19324D')}}]
        elif kind=='tableEx':
            objects['grid']=[{'properties':{'textSize':lit('12D')}}]
            objects['columnHeaders']=[{'properties':{'fontColor':color('#19324D'),'backColor':color('#E8F0F8'),'fontSize':lit('12D')}}]
        elif kind=='slicer':
            objects['data']=[{'properties':{'mode':lit("'Dropdown'")}}]
            objects['items']=[{'properties':{'fontSize':lit('13D'),'fontColor':color('#19324D')}}]
        write(p,obj)
    textbox(page,'heading',titles[page.name],20,0,1400,64,22,True)
    textbox(page,'disclosure','SYNTHETIC DATA  |  May–Oct 2026  |  PM snapshot: 31 Oct 2026',20,53,1400,40,12)
    if page.name=='overview':
        old=page/'visuals/assumptions/visual.json'
        if old.exists():old.unlink()
        textbox(page,'assumptions','MTBF is an estimate: (planned production hours − unplanned downtime) / breakdowns.\nCalendar: 2 shifts × 8 hours × 26 days per month = 2,496 hours per machine over six months.\nChoose month, production line or machine above to inspect the same scope across visuals.',20,625,1400,150,16)
    if page.name=='pm':
        textbox(page,'pmnote','Compliance uses tasks due in the selected period; cancelled tasks are excluded. Late completion is not on-time. Snapshot status is not a historical reconstruction.',20,855,1400,45,11)
print('Polished existing report bindings and labels.')
