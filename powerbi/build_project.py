"""Build editable PBIP/PBIR with SQL import model. Desktop validation is separate."""
from pathlib import Path
import json
import uuid

ROOT=Path(__file__).resolve().parent
BASE='https://developer.microsoft.com/json-schemas/fabric/item/'
def write(path,obj):
    path=ROOT/path;path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(obj,indent=2,ensure_ascii=False),encoding='utf-8')

write(Path('Maintenance_Analytics.pbip'),{'version':'1.0','artifacts':[{'report':{'path':'Maintenance.Report'}}],'settings':{'enableAutoRecovery':True}})
write(Path('Maintenance.Report/definition.pbir'),{'$schema':BASE+'report/definitionProperties/2.0.0/schema.json','version':'4.0','datasetReference':{'byPath':{'path':'../Maintenance.SemanticModel'}}})
write(Path('Maintenance.SemanticModel/definition.pbism'),{'version':'1.0','settings':{}})

definitions={
 'Dim_Machine': [('Machine_ID','string'),('Machine_Name','string'),('Line_ID','string'),('Criticality','string')],
 'vw_Breakdown_Analysis': [('Maintenance_ID','string'),('Machine_ID','string'),('Date','dateTime'),('Type','string'),('Failure_Mode','string'),('Duration_Hours','double'),('Downtime_Hours','double'),('Status','string'),('Event_Day','dateTime'),('Is_Breakdown','int64')],
 'vw_PM_Performance': [('PM_ID','string'),('Machine_ID','string'),('PM_Type','string'),('Due_Date','dateTime'),('Completed_Date','dateTime'),('Status','string'),('Eligible_Due','int64'),('On_Time','int64'),('Alert_Status','string')],
 'Dim_Date': [('Date','dateTime'),('YearMonth','string'),('ScheduledHours','int64')],
}
tables=[]
for name,columns in definitions.items():
    sql_columns=','.join('['+c+']' for c,_ in columns)
    m=f'let Data = Sql.Database("localhost", "MaintenancePlanningJD", [Query="SELECT {sql_columns} FROM dbo.[{name}]",CreateNavigationProperties=false]) in Data'
    if name=='Dim_Date':
        m='let Source=Table.FromList(List.Dates(#date(2026,5,1),184,#duration(1,0,0,0)),Splitter.SplitByNothing(),{"Date"}), Typed=Table.TransformColumnTypes(Source,{{"Date",type datetime}}), Month=Table.AddColumn(Typed,"YearMonth",each Date.ToText(Date.From([Date]),"yyyy-MM"),type text), Hours=Table.AddColumn(Month,"ScheduledHours",each if Date.Day([Date])<=26 then 16 else 0,Int64.Type) in Hours'
    cols=[{'name':c,'dataType':dtype,'sourceColumn':c,'summarizeBy':'none',**({'formatString':'yyyy-MM-dd'} if dtype=='dateTime' else {})} for c,dtype in columns]
    tables.append({'name':name,'columns':cols,'partitions':[{'name':name,'mode':'import','source':{'type':'m','expression':m}}]})
# May through October contains 184 calendar days. All six months included.
measures={
 'Total Downtime Hours':'SUM(vw_Breakdown_Analysis[Downtime_Hours])',
 'Breakdown Count':'VAR n = CALCULATE(COUNTROWS(vw_Breakdown_Analysis),vw_Breakdown_Analysis[Type]="Corrective") RETURN IF(ISINSCOPE(vw_Breakdown_Analysis[Failure_Mode]),n,COALESCE(n,0))',
 'Corrective Repair Hours':'CALCULATE(SUM(vw_Breakdown_Analysis[Duration_Hours]), vw_Breakdown_Analysis[Type] = "Corrective")',
 'MTTR':'DIVIDE([Corrective Repair Hours], [Breakdown Count])',
 'Planned Production Hours':'SUM(Dim_Date[ScheduledHours]) * COUNTROWS(VALUES(Dim_Machine[Machine_ID]))',
 'MTBF':'DIVIDE([Planned Production Hours]-[Total Downtime Hours],[Breakdown Count])',
 'PM Tasks Due':'SUM(vw_PM_Performance[Eligible_Due])',
 'On Time PM':'SUM(vw_PM_Performance[On_Time])',
 'PM Compliance Rate':'DIVIDE([On Time PM],[PM Tasks Due])',
 'Overdue PM Count':'CALCULATE(COUNTROWS(vw_PM_Performance),vw_PM_Performance[Alert_Status]="Overdue")',
 'Due Soon PM Count':'CALCULATE(COUNTROWS(vw_PM_Performance),vw_PM_Performance[Alert_Status]="Due Soon")',
}
for name in ['Total Downtime Hours','Breakdown Count','PM Tasks Due','On Time PM','Overdue PM Count','Due Soon PM Count']:
    measures[name]='COALESCE('+measures[name]+',0)'
tables[0]['measures']=[{'name':n,'expression':expr,'formatString':'0.00%' if n=='PM Compliance Rate' else '#,0' if n in ['Breakdown Count','PM Tasks Due','On Time PM','Overdue PM Count','Due Soon PM Count'] else '#,0.00'} for n,expr in measures.items()]
relationships=[]
for table,col in [('vw_Breakdown_Analysis','Machine_ID'),('vw_PM_Performance','Machine_ID')]:
    relationships.append({'name':str(uuid.uuid4()),'fromTable':table,'fromColumn':col,'toTable':'Dim_Machine','toColumn':'Machine_ID','crossFilteringBehavior':'oneDirection'})
for table,col in [('vw_Breakdown_Analysis','Event_Day'),('vw_PM_Performance','Due_Date')]:
    relationships.append({'name':str(uuid.uuid4()),'fromTable':table,'fromColumn':col,'toTable':'Dim_Date','toColumn':'Date','crossFilteringBehavior':'oneDirection'})
write(Path('Maintenance.SemanticModel/model.bim'),{'name':'MaintenancePlanning','compatibilityLevel':1600,'model':{'culture':'en-US','defaultPowerBIDataSourceVersion':'powerBI_V3','tables':tables,'relationships':relationships,'annotations':[{'name':'__PBI_TimeIntelligenceEnabled','value':'0'}]}})

prefix=Path('Maintenance.Report/definition')
write(prefix/'version.json',{'$schema':BASE+'report/definition/versionMetadata/1.0.0/schema.json','version':'2.0.0'})
write(prefix/'report.json',{'$schema':BASE+'report/definition/report/3.1.0/schema.json','themeCollection':{},'annotations':[{'name':'SyntheticNotice','value':'Fully synthetic | May-Oct 2026 | PM snapshot 31 Oct 2026 | MTBF estimated'}]})
pages=[('overview','Maintenance Overview'),('reliability','Machine Reliability'),('pm','PM Performance')]
write(prefix/'pages/pages.json',{'$schema':BASE+'report/definition/pagesMetadata/1.0.0/schema.json','pageOrder':[p[0] for p in pages],'activePageName':'overview'})
def field(table,column,measure=False):
    return {'Measure' if measure else 'Column':{'Expression':{'SourceRef':{'Entity':table}},'Property':column}}
def projection(table,column,measure=False):return {'field':field(table,column,measure),'queryRef':f'{table}.{column}','nativeQueryRef':column}
def visual(page,name,kind,x,y,width,height,roles,title):
    def lit(v): return {"expr":{"Literal":{"Value":v}}}
    title_properties={"show":lit("true"),"text":lit("'"+title.replace("'","''")+"'")}
    obj={"$schema":BASE+"report/definition/visualContainer/2.1.0/schema.json","name":name,"position":{"x":x,"y":y,"z":0,"height":height,"width":width,"tabOrder":0},"visual":{"visualType":kind,"query":{"queryState":{role:{"projections":items} for role,items in roles.items()}},"visualContainerObjects":{"title":[{"properties":title_properties}]}}}
    write(prefix/f'pages/{page}/visuals/{name}/visual.json',obj)
for page,title in pages:
    write(prefix/f'pages/{page}/page.json',{'$schema':BASE+'report/definition/page/2.0.0/schema.json','name':page,'displayName':title+' | Synthetic','displayOption':'FitToPage','height':900,'width':1440})
    for i,(table,col) in enumerate([('Dim_Date','YearMonth'),('Dim_Machine','Line_ID'),('Dim_Machine','Machine_ID')]):
        visual(page,f'slicer{i}','slicer',20+i*465,10,450,110,{'Values':[projection(table,col)]},col)
    cards=['Total Downtime Hours','Breakdown Count','MTTR','MTBF'] if page!='pm' else ['PM Compliance Rate','PM Tasks Due','Overdue PM Count','Due Soon PM Count']
    for i,measure in enumerate(cards):visual(page,f'card{i}','card',20+i*355,130,340,120,{'Values':[projection('Dim_Machine',measure,True)]},measure)
    if page=='overview':
        charts=[('lineChart','Dim_Date','YearMonth','Total Downtime Hours','Monthly downtime (hours)'),('clusteredBarChart','Dim_Machine','Line_ID','Total Downtime Hours','Downtime by production line (hours)')]
    elif page=='reliability':
        charts=[('clusteredBarChart','Dim_Machine','Machine_ID','Total Downtime Hours','Downtime by machine (hours)'),('lineChart','Dim_Date','YearMonth','Breakdown Count','Monthly breakdowns')]
    else:
        charts=[('clusteredBarChart','Dim_Machine','Line_ID','PM Compliance Rate','On-time PM compliance by line'),('clusteredBarChart','Dim_Machine','Machine_ID','PM Compliance Rate','On-time PM compliance by machine')]
    for i,(kind,table,col,measure,title) in enumerate(charts):visual(page,f'chart{i}',kind,20+i*710,270,690,300,{'Category':[projection(table,col)],'Y':[projection('Dim_Machine',measure,True)]},title)
    if page=='pm':
        values=[projection('vw_PM_Performance',c) for c in ['PM_ID','Machine_ID','Due_Date','Completed_Date','Status','Alert_Status']]
        visual(page,'tasks','tableEx',20,590,1400,280,{'Values':values},'PM task follow-up | Snapshot 31 Oct 2026')
    elif page=='reliability':
        visual(page,'failures','clusteredBarChart',20,590,690,280,{'Category':[projection('vw_Breakdown_Analysis','Failure_Mode')],'Y':[projection('Dim_Machine','Breakdown Count',True)]},'Repeated failure modes (corrective count)')
        visual(page,'machinebreakdowns','clusteredBarChart',730,590,690,280,{'Category':[projection('Dim_Machine','Machine_ID')],'Y':[projection('Dim_Machine','Breakdown Count',True)]},'Breakdowns by machine')
    else:
        visual(page,'assumptions','tableEx',20,590,1400,280,{'Values':[projection('Dim_Machine',m,True) for m in ['Planned Production Hours','Total Downtime Hours','Breakdown Count','MTTR','MTBF']]},'Synthetic May-Oct 2026 | 2 shifts x 8h x 26 days/month | Estimated MTBF')
print('PBIP generated; Desktop open/refresh verification required.')
