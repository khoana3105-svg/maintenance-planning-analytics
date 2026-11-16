import argparse
import json
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4
import pandas as pd
from .config import ROOT, FILES
from .validate_data import validate
from .transform_data import transform
from .load_sql import load_sql


def run(source, validate_only=False):
    batch=ROOT/'outputs'/('run_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S')+'_'+uuid4().hex[:6])
    batch.mkdir(parents=True)
    summary={'Batch_ID':batch.name,'Started_UTC':datetime.now(timezone.utc).isoformat(),'Source':str(source.resolve()),'Status':'FAILED'}
    try:
        raw={k:pd.read_csv(source/f'{k}.csv',encoding='utf-8-sig',dtype=str,keep_default_na=False) for k in FILES}
        clean,rejected=validate(raw)
        summary.update(Source_Rows=sum(map(len,raw.values())),Accepted_Rows=sum(map(len,clean.values())),Rejected_Rows=len(rejected))
        assert summary['Source_Rows']==summary['Accepted_Rows']+summary['Rejected_Rows']
        rejected.to_csv(batch/'rejected_records.csv',index=False,encoding='utf-8-sig')
        for k,df in transform(clean).items():df.to_csv(batch/f'{k}.csv',index=False,encoding='utf-8-sig')
        (batch/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
        if validate_only:
            summary['Status']='VALIDATED_ONLY'
        else:
            summary['SQL_Result']=load_sql(batch)
            summary['Status']='SUCCESS'
    except Exception as exc:
        summary['Error']=str(exc)
        raise
    finally:
        summary['Finished_UTC']=datetime.now(timezone.utc).isoformat()
        (batch/'summary.json').write_text(json.dumps(summary,indent=2),encoding='utf-8')
        print(json.dumps(summary,indent=2))
    return batch


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--source',type=Path,required=True);p.add_argument('--validate-only',action='store_true')
    args=p.parse_args();run(args.source,args.validate_only)
