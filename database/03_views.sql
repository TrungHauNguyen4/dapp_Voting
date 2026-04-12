USE VotingDApp;
GO

IF OBJECT_ID('voting.vwElectionSummary', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwElectionSummary;
END;
GO

CREATE VIEW voting.vwElectionSummary
AS
SELECT
    e.ElectionId,
    e.ContractAddress,
    e.ChainId,
    e.State,
    e.StartTimeUtc,
    e.EndTimeUtc,
    COUNT(DISTINCT c.CandidateRowId) AS CandidateCount,
    COUNT(DISTINCT v.VoteId) AS VoteCount,
    COUNT(DISTINCT w.WhitelistId) AS WhitelistCount,
    e.CreatedAtUtc
FROM voting.Elections e
LEFT JOIN voting.Candidates c ON c.ElectionId = e.ElectionId
LEFT JOIN voting.Votes v ON v.ElectionId = e.ElectionId
LEFT JOIN voting.Whitelist w ON w.ElectionId = e.ElectionId
GROUP BY
    e.ElectionId,
    e.ContractAddress,
    e.ChainId,
    e.State,
    e.StartTimeUtc,
    e.EndTimeUtc,
    e.CreatedAtUtc;
GO
