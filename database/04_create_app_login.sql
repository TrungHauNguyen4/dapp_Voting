IF NOT EXISTS (SELECT 1 FROM sys.sql_logins WHERE name = 'votingapp_local')
BEGIN
    CREATE LOGIN votingapp_local WITH PASSWORD = 'VotingDApp@2026!', CHECK_POLICY = OFF;
END;
GO

USE VotingDApp;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'votingapp_local')
BEGIN
    CREATE USER votingapp_local FOR LOGIN votingapp_local;
END;
GO

ALTER ROLE db_datareader ADD MEMBER votingapp_local;
ALTER ROLE db_datawriter ADD MEMBER votingapp_local;
GO
