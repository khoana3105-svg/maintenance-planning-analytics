CREATE OR ALTER VIEW dbo.vw_Machine_Downtime AS
WITH Months AS (
 SELECT DATEFROMPARTS(2026,v.m,1) AS Month_Start FROM (VALUES(5),(6),(7),(8),(9),(10)) v(m)
), Agg AS (
 SELECT Machine_ID,DATEFROMPARTS(YEAR([Date]),MONTH([Date]),1) AS Month_Start,
 SUM(CASE WHEN [Type]='Corrective' THEN Downtime_Hours ELSE 0 END) AS Downtime_Hours,
 SUM(CASE WHEN [Type]='Corrective' THEN 1 ELSE 0 END) AS Breakdown_Count,
 SUM(CASE WHEN [Type]='Corrective' THEN Duration_Hours ELSE 0 END) AS Repair_Hours
 FROM dbo.Fact_Maintenance GROUP BY Machine_ID,DATEFROMPARTS(YEAR([Date]),MONTH([Date]),1)
)
SELECT m.Machine_ID,m.Machine_Name,m.Line_ID,m.Criticality,d.Month_Start,
 CAST(416 AS decimal(12,2)) AS Planned_Hours,
 COALESCE(a.Downtime_Hours,0) AS Downtime_Hours,COALESCE(a.Breakdown_Count,0) AS Breakdown_Count,
 a.Repair_Hours/NULLIF(a.Breakdown_Count,0) AS MTTR,
 (416-COALESCE(a.Downtime_Hours,0))/NULLIF(a.Breakdown_Count,0) AS MTBF
FROM dbo.Dim_Machine m CROSS JOIN Months d
LEFT JOIN Agg a ON a.Machine_ID=m.Machine_ID AND a.Month_Start=d.Month_Start;
GO
CREATE OR ALTER VIEW dbo.vw_Breakdown_Analysis AS
SELECT f.*,CAST(f.[Date] AS date) AS Event_Day,m.Machine_Name,m.Line_ID,m.Criticality,
 CASE WHEN f.[Type]='Corrective' THEN 1 ELSE 0 END AS Is_Breakdown,
 ROW_NUMBER() OVER(PARTITION BY f.Machine_ID,f.Failure_Mode ORDER BY f.[Date],f.Maintenance_ID) AS Occurrence_Number
FROM dbo.Fact_Maintenance f JOIN dbo.Dim_Machine m ON f.Machine_ID=m.Machine_ID;
GO
CREATE OR ALTER VIEW dbo.vw_PM_Performance AS
SELECT p.*,m.Machine_Name,m.Line_ID,m.Criticality,
 CASE WHEN p.[Status]<>'Cancelled' AND p.Due_Date<='20261031' THEN 1 ELSE 0 END AS Eligible_Due,
 CASE WHEN p.[Status]='Completed' AND p.Completed_Date<=p.Due_Date AND p.Due_Date<='20261031' THEN 1 ELSE 0 END AS On_Time,
 CASE WHEN p.[Status] IN ('Completed','Cancelled') THEN p.[Status]
 WHEN p.Due_Date<'20261031' THEN 'Overdue'
 WHEN p.Due_Date<=DATEADD(day,7,CAST('20261031' AS date)) THEN 'Due Soon'
 ELSE 'Upcoming' END AS Alert_Status
FROM dbo.Fact_PM_Schedule p JOIN dbo.Dim_Machine m ON p.Machine_ID=m.Machine_ID;
