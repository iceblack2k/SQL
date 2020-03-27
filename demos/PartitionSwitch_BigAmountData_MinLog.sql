/*
	Partition demo with split and SWITCH a big volumne of data
	Move not partitioned data to staging table
	Rebuild index on staging table with(DROP_EXISTING=ON)
	Table switch
*/
CREATE PARTITION FUNCTION fn_schemename(DATETIME)
	AS RANGE RIGHT FOR VALUES (
	                              N'2011-01-01T00:00:00.000',
	                              N'2011-04-01T00:00:00.000',
	                              N'2011-07-01T00:00:00.000',
	                              N'2011-10-01T00:00:00.000',
	                              N'2012-01-01T00:00:00.000'
	                          )

CREATE PARTITION SCHEME fn_schemename
AS PARTITION fn_schemename
	ALL TO ([PRIMARY])


CREATE TABLE dbo.PartitionedTable
(
	PartitioningColumn     DATETIME NOT NULL,
	OtherColumn            INT NOT NULL
) ON fn_schemename(PartitioningColumn);

--Generate dummy data 10M rows
--00:02:05
DECLARE @StartDate datetime = '20110101'
		,@EndDate datetime = '20160218'
		,@Starti float 
		,@Endi float 
SELECT @Starti = convert(float,@StartDate),@Endi = converT(float,@EndDate)

INSERT INTO dbo.PartitionedTable
SELECT TOP 10000000
       CONVERT(DATETIME,(@Endi -@Starti) * RAND(CHECKSUM(NEWID())) + @Starti) randomnumber,
       RAND(CHECKSUM(NEWID()))
FROM   sys.all_columns ac1
       CROSS JOIN sys.all_columns     ac2


--00:01:44
CREATE CLUSTERED INDEX cdx_PartitionedTable ON dbo.PartitionedTable
	(
		PartitioningColumn
	) ON fn_schemename(PartitioningColumn)
--00:01:53
CREATE NONCLUSTERED INDEX idx_PartitionedTable_1 ON dbo.PartitionedTable
	(
		OtherColumn
	) ON fn_schemename(PartitioningColumn)

CREATE PARTITION FUNCTION fn_schemename_staging(DATETIME)
	AS RANGE RIGHT FOR VALUES (
	                              N'2011-01-01T00:00:00.000',
	                              N'2011-04-01T00:00:00.000',
	                              N'2011-07-01T00:00:00.000',
	                              N'2011-10-01T00:00:00.000',
	                              N'2012-01-01T00:00:00.000',
	                              N'2012-04-01T00:00:00.000',
	                              N'2012-07-01T00:00:00.000',
	                              N'2012-10-01T00:00:00.000',
	                              N'2013-01-01T00:00:00.000',
	                              N'2013-04-01T00:00:00.000',
	                              N'2013-07-01T00:00:00.000',
	                              N'2013-10-01T00:00:00.000'
	                          )

CREATE PARTITION SCHEME fn_schemename_staging
AS PARTITION fn_schemename_staging
	ALL TO ([PRIMARY])

--create staging table on old partition scheme
CREATE TABLE dbo.PartitionedTable_staging(
	PartitioningColumn datetime NOT NULL
	,OtherColumn int NOT NULL
	) ON fn_schemename(PartitioningColumn);

CREATE CLUSTERED INDEX cdx_PartitionedTable_staging ON dbo.PartitionedTable_staging
	(
		PartitioningColumn
	) ON fn_schemename(PartitioningColumn)

CREATE NONCLUSTERED INDEX idx_PartitionedTable_staging_1 ON dbo.PartitionedTable_staging
	(
		OtherColumn
	) ON fn_schemename(PartitioningColumn)

--Check data distributed on partitions in source table
SELECT t.name   AS TableName,
       i.name   AS IndexName,
       p.partition_number,
       r.value  AS BoundaryValue,
       p.rows,
       $PARTITION.fn_schemename_staging(N'2012-01-01T00:00:00.000')
FROM
    sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id 
JOIN sys.partition_schemes s ON i.data_space_id = s.data_space_id
JOIN sys.partition_functions f ON s.function_id = f.function_id
LEFT JOIN sys.partition_range_values AS r ON f.function_id = r.function_id AND r.boundary_id = p.partition_number
WHERE t.name = 'PartitionedTable'
AND i.type <= 1
ORDER BY p.partition_number

--move last partition to staging table
ALTER TABLE dbo.PartitionedTable
	SWITCH PARTITION $PARTITION.fn_schemename_staging(N'2012-01-01T00:00:00.000')
	TO dbo.PartitionedTable_staging PARTITION $PARTITION.fn_schemename_staging(N'2012-01-01T00:00:00.000');


--Check data distributed on partitions in target table
SELECT t.name   AS TableName,
       i.name   AS IndexName,
       p.partition_number,
       r.value  AS BoundaryValue,
       p.rows,
       $PARTITION.fn_schemename_staging(N'2012-01-01T00:00:00.000')
FROM
    sys.tables t
JOIN sys.indexes i ON t.object_id = i.object_id
JOIN sys.partitions p ON i.object_id = p.object_id AND i.index_id = p.index_id 
JOIN sys.partition_schemes s ON i.data_space_id = s.data_space_id
JOIN sys.partition_functions f ON s.function_id = f.function_id
LEFT JOIN sys.partition_range_values AS r ON f.function_id = r.function_id AND r.boundary_id = p.partition_number
WHERE t.name = 'PartitionedTable_staging'
AND i.type <= 1
ORDER BY p.partition_number

--00:04:07
--rebuild indexes on staging table using new scheme
CREATE CLUSTERED INDEX cdx_PartitionedTable_staging ON dbo.PartitionedTable_staging
	(
		PartitioningColumn
	) 
	WITH(DROP_EXISTING = ON)
	ON fn_schemename_staging(PartitioningColumn)

CREATE NONCLUSTERED INDEX idx_PartitionedTable_staging_1 ON dbo.PartitionedTable_staging
	(
		OtherColumn
	)
	WITH(DROP_EXISTING = ON)
	ON fn_schemename_staging(PartitioningColumn)
GO

--00:00:01
--split remaining partitions of original table and move data back in
DECLARE 
	@StartBoundary datetime = '2012-04-01T00:00:00.000'
	,@EndBoundary datetime = '2013-10-01T00:00:00.000';
WHILE @StartBoundary <= @EndBoundary
BEGIN
	ALTER PARTITION SCHEME fn_schemename
		NEXT USED [PRIMARY];
	--split original partition
	ALTER PARTITION FUNCTION fn_schemename()
		SPLIT RANGE(@StartBoundary);
	--move partition back to table
	ALTER TABLE dbo.PartitionedTable_staging
		SWITCH PARTITION $PARTITION.fn_schemename_staging(DATEADD(month, -3, @StartBoundary))
		TO dbo.PartitionedTable PARTITION $PARTITION.fn_schemename(DATEADD(month, -3, @StartBoundary));
	SET @StartBoundary = DATEADD(month, 3, @StartBoundary);
END
GO