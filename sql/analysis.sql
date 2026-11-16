-- Run in MaintenancePlanningJD; every row below is synthetic.
-- Total downtime leaders, including machines without breakdowns (LEFT JOIN in view).
SELECT Machine_ID,SUM(Downtime_Hours) AS Downtime_Hours,SUM(Breakdown_Count) AS Breakdowns,
 SUM(Planned_Hours-Downtime_Hours)/NULLIF(SUM(Breakdown_Count),0) AS MTBF
FROM dbo.vw_Machine_Downtime GROUP BY Machine_ID ORDER BY Downtime_Hours DESC;
-- Repeated failure modes; one maintenance row is one event.
SELECT Machine_ID,Failure_Mode,COUNT(*) AS Occurrences
FROM dbo.vw_Breakdown_Analysis WHERE Is_Breakdown=1
GROUP BY Machine_ID,Failure_Mode HAVING COUNT(*)>1 ORDER BY Occurrences DESC;
-- Monthly PM compliance by line, due-date cohort. No join between two fact tables.
SELECT Line_ID,YEAR(Due_Date) AS [Year],MONTH(Due_Date) AS [Month],
 SUM(On_Time)*1.0/NULLIF(SUM(Eligible_Due),0) AS PM_Compliance
FROM dbo.vw_PM_Performance GROUP BY Line_ID,YEAR(Due_Date),MONTH(Due_Date);
