import tempfile
import unittest
from pathlib import Path
import pandas as pd
from src.generate_data import generate
from src.validate_data import validate
from src.transform_data import pm_alert
from src.config import FILES


class PipelineTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory()
        cls.folder=Path(cls.temp.name)/'source'
        generate(cls.folder)
        cls.raw={k:pd.read_csv(cls.folder/f'{k}.csv',dtype=str,keep_default_na=False) for k in FILES}

    @classmethod
    def tearDownClass(cls):cls.temp.cleanup()

    def test_reproducibility(self):
        other=Path(self.temp.name)/'repeat';generate(other)
        for k in FILES:self.assertEqual((self.folder/f'{k}.csv').read_bytes(),(other/f'{k}.csv').read_bytes())

    def test_reconciliation_and_scope(self):
        good,bad=validate(self.raw)
        total=sum(map(len,self.raw.values()))
        self.assertEqual(total,sum(map(len,good.values()))+len(bad))
        self.assertTrue(500<=total<=800)
        self.assertTrue(.03<=len(bad)/total<=.05)
        self.assertEqual(len(good['machines']),20)
        self.assertEqual(len(good['machines']['Line_ID'].unique()),4)

    def test_missing_date_and_nan_infinity_rejected(self):
        for field,value in [('Date',''),('Duration_Hours','NaN'),('Duration_Hours','inf'),('Downtime_Hours','-1'),('Machine_ID','M999')]:
            raw={k:v.copy() for k,v in self.raw.items()};raw['maintenance_records'].loc[0,field]=value
            good,bad=validate(raw)
            self.assertTrue(((bad.Source=='maintenance_records') & (bad.Source_Row==2)).any(),(field,value))

    def test_schema_missing(self):
        raw={k:v.copy() for k,v in self.raw.items()};raw['machines']=raw['machines'].drop(columns=['Line_ID'])
        with self.assertRaises(ValueError):validate(raw)

    def test_pm_consistency(self):
        raw={k:v.copy() for k,v in self.raw.items()};raw['pm_schedule'].loc[0,'Completed_Date']=''
        good,bad=validate(raw)
        self.assertTrue(((bad.Source=='pm_schedule') & (bad.Source_Row==2)).any())

    def test_pm_boundaries(self):
        for due,expected in [('2026-10-30','Overdue'),('2026-10-31','Due Soon'),('2026-11-07','Due Soon'),('2026-11-08','Upcoming')]:
            self.assertEqual(pm_alert('Planned',due,'2026-10-31'),expected)
        self.assertEqual(pm_alert('Cancelled','2026-10-01','2026-10-31'),'Cancelled')

    def test_scenarios(self):
        good,_=validate(self.raw)
        m=good['maintenance_records'];corrective=m[m.Type=='Corrective']
        self.assertEqual(corrective.groupby('Machine_ID').Downtime_Hours.sum().idxmax(),'M003')
        self.assertEqual(corrective[corrective.Machine_ID=='M003'].Failure_Mode.nunique(),1)
        pm=good['pm_schedule'].merge(good['machines'][['Machine_ID','Line_ID']],on='Machine_ID',validate='many_to_one')
        pm['on_time']=(pm.Status=='Completed') & (pm.Completed_Date<=pm.Due_Date)
        rates=pm.groupby('Line_ID').on_time.mean()
        self.assertLess(rates['L01'],rates['L02'])


if __name__=='__main__':unittest.main()
