USE HRMS;
GO
-- 1. Drop all procedures
DECLARE @proc NVARCHAR(MAX) = '';
SELECT @proc += 'DROP PROCEDURE [' + name + '];'
FROM sys.procedures;
EXEC(@proc);

PRINT 'All procedures dropped.';

-- 2. Disable constraints
EXEC sp_msforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT ALL";

-- 3. Drop foreign keys
DECLARE @sql NVARCHAR(MAX) = '';
SELECT @sql += 'ALTER TABLE [' + OBJECT_NAME(parent_object_id) + '] DROP CONSTRAINT [' + name + '];'
FROM sys.foreign_keys;
EXEC sp_executesql @sql;

-- 4. Drop all tables
EXEC sp_msforeachtable "DROP TABLE ?";
PRINT 'All tables dropped.';
