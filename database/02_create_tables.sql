USE VotingDApp;
GO

IF OBJECT_ID('voting.Elections', 'U') IS NULL
BEGIN
    CREATE TABLE voting.Elections (
        ElectionId UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
        ContractAddress NVARCHAR(42) NOT NULL,
        ChainId INT NOT NULL,
        AdminAddress NVARCHAR(42) NOT NULL,
        Name NVARCHAR(200) NULL,
        Description NVARCHAR(1000) NULL,
        State NVARCHAR(20) NOT NULL,
        StartTimeUtc DATETIME2 NULL,
        EndTimeUtc DATETIME2 NULL,
        CreatedAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        LastSyncedBlock BIGINT NULL,
        CONSTRAINT PK_Elections PRIMARY KEY (ElectionId),
        CONSTRAINT CK_Elections_State CHECK (State IN ('Created', 'Voting', 'Ended')),
        CONSTRAINT UQ_Elections_Contract_Chain UNIQUE (ContractAddress, ChainId)
    );
END;
GO

IF OBJECT_ID('voting.Candidates', 'U') IS NULL
BEGIN
    CREATE TABLE voting.Candidates (
        CandidateRowId BIGINT IDENTITY(1,1) NOT NULL,
        ElectionId UNIQUEIDENTIFIER NOT NULL,
        CandidateId INT NOT NULL,
        CandidateName NVARCHAR(200) NOT NULL,
        ImageUrl NVARCHAR(1000) NULL,
        VoteCount BIGINT NOT NULL DEFAULT 0,
        CreatedAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_Candidates PRIMARY KEY (CandidateRowId),
        CONSTRAINT FK_Candidates_Elections FOREIGN KEY (ElectionId)
            REFERENCES voting.Elections(ElectionId) ON DELETE CASCADE,
        CONSTRAINT UQ_Candidates_Election_CandidateId UNIQUE (ElectionId, CandidateId)
    );
END;
GO

IF OBJECT_ID('voting.Whitelist', 'U') IS NULL
BEGIN
    CREATE TABLE voting.Whitelist (
        WhitelistId BIGINT IDENTITY(1,1) NOT NULL,
        ElectionId UNIQUEIDENTIFIER NOT NULL,
        WalletAddress NVARCHAR(42) NOT NULL,
        RegisteredAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        RegisteredBy NVARCHAR(42) NULL,
        CONSTRAINT PK_Whitelist PRIMARY KEY (WhitelistId),
        CONSTRAINT FK_Whitelist_Elections FOREIGN KEY (ElectionId)
            REFERENCES voting.Elections(ElectionId) ON DELETE CASCADE,
        CONSTRAINT UQ_Whitelist_Election_Wallet UNIQUE (ElectionId, WalletAddress)
    );
END;
GO

IF OBJECT_ID('voting.Votes', 'U') IS NULL
BEGIN
    CREATE TABLE voting.Votes (
        VoteId BIGINT IDENTITY(1,1) NOT NULL,
        ElectionId UNIQUEIDENTIFIER NOT NULL,
        VoterAddress NVARCHAR(42) NOT NULL,
        CandidateId INT NOT NULL,
        TransactionHash NVARCHAR(66) NOT NULL,
        BlockNumber BIGINT NOT NULL,
        VotedAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_Votes PRIMARY KEY (VoteId),
        CONSTRAINT FK_Votes_Elections FOREIGN KEY (ElectionId)
            REFERENCES voting.Elections(ElectionId) ON DELETE CASCADE,
        CONSTRAINT FK_Votes_Candidates FOREIGN KEY (ElectionId, CandidateId)
            REFERENCES voting.Candidates(ElectionId, CandidateId),
        CONSTRAINT UQ_Votes_Election_Voter UNIQUE (ElectionId, VoterAddress),
        CONSTRAINT UQ_Votes_TxHash UNIQUE (TransactionHash)
    );
END;
GO

IF OBJECT_ID('voting.EventLogs', 'U') IS NULL
BEGIN
    CREATE TABLE voting.EventLogs (
        EventLogId BIGINT IDENTITY(1,1) NOT NULL,
        ElectionId UNIQUEIDENTIFIER NULL,
        ContractAddress NVARCHAR(42) NOT NULL,
        ChainId INT NOT NULL,
        EventName NVARCHAR(100) NOT NULL,
        TransactionHash NVARCHAR(66) NOT NULL,
        BlockNumber BIGINT NOT NULL,
        LogIndex INT NOT NULL,
        PayloadJson NVARCHAR(MAX) NULL,
        CreatedAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_EventLogs PRIMARY KEY (EventLogId),
        CONSTRAINT UQ_EventLogs_Block_Log UNIQUE (ChainId, BlockNumber, TransactionHash, LogIndex)
    );
END;
GO

IF OBJECT_ID('voting.SyncState', 'U') IS NULL
BEGIN
    CREATE TABLE voting.SyncState (
        SyncStateId INT IDENTITY(1,1) NOT NULL,
        ChainId INT NOT NULL,
        ContractAddress NVARCHAR(42) NOT NULL,
        LastScannedBlock BIGINT NOT NULL,
        LastUpdatedAtUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        CONSTRAINT PK_SyncState PRIMARY KEY (SyncStateId),
        CONSTRAINT UQ_SyncState_Chain_Contract UNIQUE (ChainId, ContractAddress)
    );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Candidates_ElectionId' AND object_id = OBJECT_ID('voting.Candidates'))
BEGIN
    CREATE INDEX IX_Candidates_ElectionId ON voting.Candidates(ElectionId);
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Whitelist_ElectionId' AND object_id = OBJECT_ID('voting.Whitelist'))
BEGIN
    CREATE INDEX IX_Whitelist_ElectionId ON voting.Whitelist(ElectionId);
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Votes_ElectionId' AND object_id = OBJECT_ID('voting.Votes'))
BEGIN
    CREATE INDEX IX_Votes_ElectionId ON voting.Votes(ElectionId);
END;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_EventLogs_Contract_Block' AND object_id = OBJECT_ID('voting.EventLogs'))
BEGIN
    CREATE INDEX IX_EventLogs_Contract_Block ON voting.EventLogs(ContractAddress, BlockNumber);
END;
GO
