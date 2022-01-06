CREATE TABLE dbo.SQLSkills_StatsHistory
(
	CaptureDate                DATETIME2(7) NOT NULL DEFAULT(SYSDATETIME())
   ,DatabaseID                 INT NULL
   ,TableName                  SYSNAME NOT NULL
   ,Statistic                  SYSNAME
   ,WasAutoCreated             BIT NULL
   ,WasUserCreated             BIT NULL
   ,IsFiltered                 BIT NULL
   ,FilderDefinition           NVARCHAR(2048) NULL
   ,IsTemporary                BIT NULL
   ,StatsLastupdated           DATETIME2(7) NULL
   ,RowsInTable                BIGINT NULL
   ,RowsSampled                BIGINT NULL
   ,UnfilteredRows             BIGINT NULL
   ,PersistedSamplePercent     FLOAT NULL
   ,NORECOMPUTE                BIT
   ,HistogramSteps             INT NULL
)

--Store this query per DB into StatsHistory table
SELECT GETUTCDATE()                 AS CaptureDate 
      ,DB_NAME()                    AS DBName
      ,QUOTENAME(sh.name) + '.' + QUOTENAME(o.name) AS TableName
      ,s.name                       AS [Statistic]
      ,s.auto_created               AS WasAutoCreated
      ,s.user_created               AS WasUserCreated
      ,s.has_filter                 AS IsFiltered
      ,s.filter_definition          AS FilterDefinition
      ,s.is_temporary               AS IsTemporary
      ,sp.last_updated              AS StatsLastUpdated
      ,sp.[rows]                    AS RowsInTable
      ,sp.rows_sampled              AS RowsSampled
      ,sp.unfiltered_rows           AS UnfilteredRows
      ,sp.modification_counter      AS RowsModifications
      ,sp.persisted_sample_percent  AS PerssitedSamplePercent
      ,s.no_recompute               AS [NoRecompute]
      ,sp.steps                     AS HistogramSteps
FROM   sys.stats s
       JOIN sys.objects o ON  o.object_id = s.object_id
       JOIN sys.schemas sh ON  sh.schema_id = o.schema_id
       OUTER APPLY sys.dm_db_stats_properties(o.object_id ,s.stats_id) sp
WHERE  o.[type] = 'U'
ORDER BY o.name,sh.name

--Query Stats got by
--See infor for specific CaptureDateTime
ORDER BY StatsLastUpdated
ORDER BY RowsInTable DESC
ORDER BY RowModifications DESC
--See Stats History prior to specific datetime


--Analyze column Skew
https://www.sqlskills.com/blogs/kimberly/sqlskills-procs-analyze-data-skew-create-filtered-statistics/