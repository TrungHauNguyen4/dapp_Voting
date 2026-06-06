-- Migration script: Tối ưu database
-- Xóa bảng không cần thiết và thêm views trực quan hơn

USE VotingDApp;
GO

-- 1. Xóa bảng NhatKySuKien (chỉ dùng cho debug, không cần thiết cho báo cáo)
IF OBJECT_ID('voting.NhatKySuKien', 'U') IS NOT NULL
BEGIN
    DROP TABLE voting.NhatKySuKien;
    PRINT 'Đã xóa bảng voting.NhatKySuKien';
END
ELSE
BEGIN
    PRINT 'Bảng voting.NhatKySuKien không tồn tại';
END
GO

-- 2. Xóa view cũ
IF OBJECT_ID('voting.vwTongHopBauCu', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwTongHopBauCu;
    PRINT 'Đã xóa view vwTongHopBauCu cũ';
END
GO

-- 3. Tạo view tổng hợp cuộc bầu cử (cập nhật)
CREATE VIEW voting.vwTongHopBauCu
AS
SELECT
    d.MaDotBauCu AS ElectionId,
    d.MaDotBauCuCu AS ElectionNumber,
    d.ElectionIdOnChain AS ChainElectionId,
    d.DiaChiHopDong AS ContractAddress,
    d.MaMang AS ChainId,
    d.DiaChiQuanTri AS AdminAddress,
    d.TrangThai AS State,
    d.BatDauLucUtc AS StartTimeUtc,
    d.KetThucLucUtc AS EndTimeUtc,
    d.TaoLucUtc AS CreatedAtUtc,
    COUNT(DISTINCT u.MaDongUngCuVien) AS CandidateCount,
    COUNT(DISTINCT p.MaPhieu) AS VoteCount,
    COUNT(DISTINCT t.MaTrang) AS WhitelistCount,
    d.BlockDongBoGanNhat AS LastSyncedBlock
FROM voting.DotBauCu d
LEFT JOIN voting.UngCuVien u ON u.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.PhieuBau p ON p.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.DanhSachTrang t ON t.MaDotBauCu = d.MaDotBauCu
GROUP BY
    d.MaDotBauCu,
    d.MaDotBauCuCu,
    d.ElectionIdOnChain,
    d.DiaChiHopDong,
    d.MaMang,
    d.DiaChiQuanTri,
    d.TrangThai,
    d.BatDauLucUtc,
    d.KetThucLucUtc,
    d.TaoLucUtc,
    d.BlockDongBoGanNhat;
GO

PRINT 'Đã tạo view vwTongHopBauCu mới';
GO

-- 4. Tạo view lịch sử các cuộc bầu cử (theo thời gian)
IF OBJECT_ID('voting.vwLichSuBauCu', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwLichSuBauCu;
    PRINT 'Đã xóa view vwLichSuBauCu cũ';
END
GO

CREATE VIEW voting.vwLichSuBauCu
AS
SELECT
    d.MaDotBauCu AS ElectionId,
    d.MaDotBauCuCu AS ElectionNumber,
    d.TenDot AS ElectionName,
    d.TrangThai AS State,
    d.BatDauLucUtc AS StartTimeUtc,
    d.KetThucLucUtc AS EndTimeUtc,
    d.TaoLucUtc AS CreatedAtUtc,
    CASE 
        WHEN d.TrangThai = 'Ended' THEN 'Đã kết thúc'
        WHEN d.TrangThai = 'Voting' THEN 'Đang bầu cử'
        WHEN d.TrangThai = 'Created' THEN 'Đã tạo'
        ELSE 'Không xác định'
    END AS StateText,
    CASE 
        WHEN d.TrangThai = 'Ended' THEN 
            (SELECT TOP 1 u.TenUngCuVien 
             FROM voting.UngCuVien u 
             WHERE u.MaDotBauCu = d.MaDotBauCu 
             ORDER BY u.SoPhieu DESC)
        ELSE NULL
    END AS Winner,
    COUNT(DISTINCT p.MaPhieu) AS TotalVotes,
    COUNT(DISTINCT t.MaTrang) AS TotalVoters
FROM voting.DotBauCu d
LEFT JOIN voting.PhieuBau p ON p.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.DanhSachTrang t ON t.MaDotBauCu = d.MaDotBauCu
GROUP BY
    d.MaDotBauCu,
    d.MaDotBauCuCu,
    d.TenDot,
    d.TrangThai,
    d.BatDauLucUtc,
    d.KetThucLucUtc,
    d.TaoLucUtc;
GO

PRINT 'Đã tạo view vwLichSuBauCu';
GO

-- 5. Tạo view kết quả bầu cử chi tiết
IF OBJECT_ID('voting.vwKetQuaBauCu', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwKetQuaBauCu;
    PRINT 'Đã xóa view vwKetQuaBauCu cũ';
END
GO

CREATE VIEW voting.vwKetQuaBauCu
AS
SELECT
    d.MaDotBauCu AS ElectionId,
    d.MaDotBauCuCu AS ElectionNumber,
    d.TenDot AS ElectionName,
    u.MaUngCuVien AS CandidateId,
    u.TenUngCuVien AS CandidateName,
    u.AnhUrl AS ImageUrl,
    u.SoPhieu AS VoteCount,
    CAST(u.SoPhieu * 100.0 / NULLIF(SUM(u.SoPhieu) OVER (PARTITION BY d.MaDotBauCu), 0) AS DECIMAL(5,2)) AS VotePercentage,
    CASE 
        WHEN u.SoPhieu = (SELECT MAX(SoPhieu) FROM voting.UngCuVien WHERE MaDotBauCu = d.MaDotBauCu) 
             AND u.SoPhieu > 0 
        THEN 1 
        ELSE 0 
    END AS IsWinner
FROM voting.DotBauCu d
INNER JOIN voting.UngCuVien u ON u.MaDotBauCu = d.MaDotBauCu
WHERE d.TrangThai = 'Ended';
GO

PRINT 'Đã tạo view vwKetQuaBauCu';
GO

-- 6. Tạo view danh sách cử tri đã bỏ phiếu
IF OBJECT_ID('voting.vwCuTriDaBau', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwCuTriDaBau;
    PRINT 'Đã xóa view vwCuTriDaBau cũ';
END
GO

CREATE VIEW voting.vwCuTriDaBau
AS
SELECT
    d.MaDotBauCu AS ElectionId,
    d.MaDotBauCuCu AS ElectionNumber,
    d.TenDot AS ElectionName,
    p.DiaChiCuTri AS VoterAddress,
    u.TenUngCuVien AS VotedFor,
    p.MaGiaoDich AS TransactionHash,
    p.SoKhoi AS BlockNumber,
    p.BauLucUtc AS VotedAtUtc
FROM voting.DotBauCu d
INNER JOIN voting.PhieuBau p ON p.MaDotBauCu = d.MaDotBauCu
INNER JOIN voting.UngCuVien u ON u.MaDotBauCu = p.MaDotBauCu AND u.MaUngCuVien = p.MaUngCuVien;
GO

PRINT 'Đã tạo view vwCuTriDaBau';
GO

PRINT 'Hoàn tất tối ưu database!';
