IF OBJECT_ID('dbo.Dim_Machine') IS NULL
CREATE TABLE dbo.Dim_Machine (
 Machine_ID varchar(20) NOT NULL PRIMARY KEY,
 Machine_Name nvarchar(100) NOT NULL,
 Line_ID varchar(20) NOT NULL,
 Criticality varchar(10) NOT NULL CHECK (Criticality IN ('High','Medium','Low'))
);
IF OBJECT_ID('dbo.Fact_Maintenance') IS NULL
CREATE TABLE dbo.Fact_Maintenance (
 Maintenance_ID varchar(40) NOT NULL PRIMARY KEY,
 Machine_ID varchar(20) NOT NULL REFERENCES dbo.Dim_Machine(Machine_ID),
 [Date] datetime2 NOT NULL,
 [Type] varchar(20) NOT NULL CHECK ([Type] IN ('Preventive','Corrective','Inspection')),
 Failure_Mode nvarchar(100) NULL,
 Duration_Hours decimal(12,2) NOT NULL CHECK (Duration_Hours>=0),
 Downtime_Hours decimal(12,2) NOT NULL CHECK (Downtime_Hours>=0),
 [Status] varchar(20) NOT NULL CHECK ([Status]='Completed'),
 CHECK ([Type]='Corrective' OR Downtime_Hours=0)
);
IF OBJECT_ID('dbo.Fact_PM_Schedule') IS NULL
CREATE TABLE dbo.Fact_PM_Schedule (
 PM_ID varchar(40) NOT NULL PRIMARY KEY,
 Machine_ID varchar(20) NOT NULL REFERENCES dbo.Dim_Machine(Machine_ID),
 PM_Type nvarchar(100) NOT NULL,
 Due_Date date NOT NULL,
 Completed_Date date NULL,
 [Status] varchar(20) NOT NULL CHECK ([Status] IN ('Planned','Completed','Cancelled')),
 CHECK (([Status]='Completed' AND Completed_Date IS NOT NULL) OR ([Status]<>'Completed' AND Completed_Date IS NULL))
);
IF OBJECT_ID('dbo.ETL_Run_Log') IS NULL
CREATE TABLE dbo.ETL_Run_Log (
 Batch_ID varchar(80) NOT NULL PRIMARY KEY,
 Started_UTC datetime2 NOT NULL, Finished_UTC datetime2 NOT NULL,
 Source_Rows int NOT NULL, Accepted_Rows int NOT NULL, Rejected_Rows int NOT NULL,
 Inserted_Rows int NOT NULL, Updated_Rows int NOT NULL, Skipped_Rows int NOT NULL,
 [Status] varchar(20) NOT NULL, Error_Message nvarchar(2000) NULL,
 CHECK (Source_Rows=Accepted_Rows+Rejected_Rows),
 CHECK ([Status]='FAILED' OR Accepted_Rows=Inserted_Rows+Updated_Rows+Skipped_Rows)
);
