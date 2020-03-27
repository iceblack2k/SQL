SELECT TOP 50
DB_NAME(t.dbid) as DBName
,t.[text] as [QueryText]
,qs.total_worker_time
,qs.total_worker_time/qs.execution_count as AvgWorkerTime
,qs.max_worker_time
,qs.total_elapsed_time/qs.execution_count as AvgElapsedTime
,qs.max_elapsed_time
,qa.total_logical_read/qs.execution_count as AvgLogicalReads
,qs.max_logical_reads
,qs.execution_count
,qs.creation_time
,qp.query_plan
from sys.dm_exec_query_stats qs with(nolock)
CROSS JOIN sys.dm_exec_sql_text(qs.plan_handle) t 
CROSS JOIN sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE CAST(qp.query_plan as NVARCHAR(MAX)) as LIKE '%CONVERT_IMPLICIT%'
AND t.dbid = DB_ID()
order by qs.total_worker_time DESC
OPTION (RECOMPILE)