USE VotingDApp;
GO

IF OBJECT_ID('voting.vwTongHopBauCu', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwTongHopBauCu;
END;
GO

CREATE VIEW voting.vwTongHopBauCu
AS
SELECT
    d.MaDotBauCu AS ElectionId,
    d.DiaChiHopDong AS ContractAddress,
    d.MaMang AS ChainId,
    d.TrangThai AS State,
    d.BatDauLucUtc AS StartTimeUtc,
    d.KetThucLucUtc AS EndTimeUtc,
    COUNT(DISTINCT u.MaDongUngCuVien) AS CandidateCount,
    COUNT(DISTINCT p.MaPhieu) AS VoteCount,
    COUNT(DISTINCT t.MaTrang) AS WhitelistCount,
    d.TaoLucUtc AS CreatedAtUtc
FROM voting.DotBauCu d
LEFT JOIN voting.UngCuVien u ON u.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.PhieuBau p ON p.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.DanhSachTrang t ON t.MaDotBauCu = d.MaDotBauCu
GROUP BY
    d.MaDotBauCu,
    d.DiaChiHopDong,
    d.MaMang,
    d.TrangThai,
    d.BatDauLucUtc,
    d.KetThucLucUtc,
    d.TaoLucUtc;
GO
