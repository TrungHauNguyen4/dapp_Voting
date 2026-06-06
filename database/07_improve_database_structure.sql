-- Migration script: Cải thiện cấu trúc database cho minh bạch và hiệu suất
-- Thêm các bảng snapshot, audit log, thống kê

USE VotingDApp;
GO

-- 1. Tạo bảng SnapshotKetQua - Lưu snapshot kết quả khi bầu cầu kết thúc
IF OBJECT_ID('voting.SnapshotKetQua', 'U') IS NOT NULL
BEGIN
    DROP TABLE voting.SnapshotKetQua;
    PRINT 'Đã xóa bảng voting.SnapshotKetQua cũ';
END
GO

CREATE TABLE voting.SnapshotKetQua (
    MaSnapshot BIGINT IDENTITY(1,1) NOT NULL,
    MaDotBauCu UNIQUEIDENTIFIER NOT NULL,
    MaDotBauCuCu INT NOT NULL,
    ThoiGianSnapshot DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    TongSoUngCuVien INT NOT NULL,
    TongSoPhieu INT NOT NULL,
    TongSoCuTri INT NOT NULL,
    UngCuVienChienThang NVARCHAR(200) NULL,
    PhieuChienThang INT NULL,
    TyLeChienThang DECIMAL(5,2) NULL,
    TrangThaiCu NVARCHAR(20) NOT NULL,
    BlockSnapshot BIGINT NOT NULL,
    HashSnapshot NVARCHAR(66) NULL,
    CONSTRAINT PK_SnapshotKetQua PRIMARY KEY (MaSnapshot),
    CONSTRAINT FK_SnapshotKetQua_DotBauCu FOREIGN KEY (MaDotBauCu)
        REFERENCES voting.DotBauCu(MaDotBauCu) ON DELETE CASCADE,
    CONSTRAINT UQ_SnapshotKetQua_Dot UNIQUE (MaDotBauCu)
);
GO

CREATE INDEX IX_SnapshotKetQua_MaDotBauCuCu ON voting.SnapshotKetQua(MaDotBauCuCu);
CREATE INDEX IX_SnapshotKetQua_ThoiGian ON voting.SnapshotKetQua(ThoiGianSnapshot DESC);
GO

PRINT 'Đã tạo bảng voting.SnapshotKetQua';
GO

-- 2. Tạo bảng AuditLog - Log các thay đổi quan trọng
IF OBJECT_ID('voting.AuditLog', 'U') IS NOT NULL
BEGIN
    DROP TABLE voting.AuditLog;
    PRINT 'Đã xóa bảng voting.AuditLog cũ';
END
GO

CREATE TABLE voting.AuditLog (
    MaAuditLog BIGINT IDENTITY(1,1) NOT NULL,
    MaDotBauCu UNIQUEIDENTIFIER NULL,
    MaDotBauCuCu INT NULL,
    LoaiHanhDong NVARCHAR(50) NOT NULL,
    ThucThe NVARCHAR(50) NOT NULL,
    NoiDung NVARCHAR(1000) NULL,
    ThucHienBoi NVARCHAR(42) NULL,
    ThoiGian DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    DuLieuCu NVARCHAR(MAX) NULL,
    DuLieuMoi NVARCHAR(MAX) NULL,
    CONSTRAINT PK_AuditLog PRIMARY KEY (MaAuditLog),
    CONSTRAINT FK_AuditLog_DotBauCu FOREIGN KEY (MaDotBauCu)
        REFERENCES voting.DotBauCu(MaDotBauCu) ON DELETE SET NULL
);
GO

CREATE INDEX IX_AuditLog_MaDotBauCu ON voting.AuditLog(MaDotBauCu);
CREATE INDEX IX_AuditLog_ThoiGian ON voting.AuditLog(ThoiGian DESC);
CREATE INDEX IX_AuditLog_LoaiHanhDong ON voting.AuditLog(LoaiHanhDong);
GO

PRINT 'Đã tạo bảng voting.AuditLog';
GO

-- 3. Tạo bảng ThongKeTongHop - Thống kê tổng hợp
IF OBJECT_ID('voting.ThongKeTongHop', 'U') IS NOT NULL
BEGIN
    DROP TABLE voting.ThongKeTongHop;
    PRINT 'Đã xóa bảng voting.ThongKeTongHop cũ';
END
GO

CREATE TABLE voting.ThongKeTongHop (
    MaThongKe BIGINT IDENTITY(1,1) NOT NULL,
    TongSoDotBauCu INT NOT NULL DEFAULT 0,
    TongSoCuTri INT NOT NULL DEFAULT 0,
    TongSoPhieu INT NOT NULL DEFAULT 0,
    CapNhatLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ThongKeTongHop PRIMARY KEY (MaThongKe)
);
GO

-- Khởi tạo thống kê tổng hợp
INSERT INTO voting.ThongKeTongHop (TongSoDotBauCu, TongSoCuTri, TongSoPhieu)
SELECT 
    (SELECT COUNT(*) FROM voting.DotBauCu),
    (SELECT COUNT(DISTINCT DiaChiVi) FROM voting.DanhSachTrang),
    (SELECT COUNT(*) FROM voting.PhieuBau);
GO

PRINT 'Đã tạo bảng voting.ThongKeTongHop';
GO

-- 4. Thêm indexes cho các bảng hiện tại để tối ưu hiệu suất
IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DotBauCu_MaDotBauCuCu' AND object_id = OBJECT_ID('voting.DotBauCu'))
BEGIN
    DROP INDEX IX_DotBauCu_MaDotBauCuCu ON voting.DotBauCu;
END
CREATE INDEX IX_DotBauCu_MaDotBauCuCu ON voting.DotBauCu(MaDotBauCuCu);
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DotBauCu_TrangThai' AND object_id = OBJECT_ID('voting.DotBauCu'))
BEGIN
    DROP INDEX IX_DotBauCu_TrangThai ON voting.DotBauCu;
END
CREATE INDEX IX_DotBauCu_TrangThai ON voting.DotBauCu(TrangThai);
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DotBauCu_TaoLucUtc' AND object_id = OBJECT_ID('voting.DotBauCu'))
BEGIN
    DROP INDEX IX_DotBauCu_TaoLucUtc ON voting.DotBauCu;
END
CREATE INDEX IX_DotBauCu_TaoLucUtc ON voting.DotBauCu(TaoLucUtc DESC);
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_UngCuVien_SoPhieu' AND object_id = OBJECT_ID('voting.UngCuVien'))
BEGIN
    DROP INDEX IX_UngCuVien_SoPhieu ON voting.UngCuVien;
END
CREATE INDEX IX_UngCuVien_SoPhieu ON voting.UngCuVien(SoPhieu DESC);
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_PhieuBau_SoKhoi' AND object_id = OBJECT_ID('voting.PhieuBau'))
BEGIN
    DROP INDEX IX_PhieuBau_SoKhoi ON voting.PhieuBau;
END
CREATE INDEX IX_PhieuBau_SoKhoi ON voting.PhieuBau(SoKhoi DESC);
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_PhieuBau_BauLucUtc' AND object_id = OBJECT_ID('voting.PhieuBau'))
BEGIN
    DROP INDEX IX_PhieuBau_BauLucUtc ON voting.PhieuBau;
END
CREATE INDEX IX_PhieuBau_BauLucUtc ON voting.PhieuBau(BauLucUtc DESC);
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_DanhSachTrang_DangKyLucUtc' AND object_id = OBJECT_ID('voting.DanhSachTrang'))
BEGIN
    DROP INDEX IX_DanhSachTrang_DangKyLucUtc ON voting.DanhSachTrang;
END
CREATE INDEX IX_DanhSachTrang_DangKyLucUtc ON voting.DanhSachTrang(DangKyLucUtc DESC);
GO

PRINT 'Đã thêm indexes cho các bảng hiện tại';
GO

-- 5. Xóa các view cũ để tạo lại
IF OBJECT_ID('voting.vwTongHopBauCu', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwTongHopBauCu;
END;
GO

IF OBJECT_ID('voting.vwLichSuBauCu', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwLichSuBauCu;
END;
GO

IF OBJECT_ID('voting.vwKetQuaBauCu', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwKetQuaBauCu;
END;
GO

IF OBJECT_ID('voting.vwCuTriDaBau', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwCuTriDaBau;
END;
GO

-- 6. Tạo lại view tổng hợp với snapshot
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
    d.BlockDongBoGanNhat AS LastSyncedBlock,
    s.ThoiGianSnapshot AS SnapshotTime,
    s.UngCuVienChienThang AS Winner,
    s.PhieuChienThang AS WinnerVotes,
    s.TyLeChienThang AS WinnerPercentage
FROM voting.DotBauCu d
LEFT JOIN voting.UngCuVien u ON u.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.PhieuBau p ON p.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.DanhSachTrang t ON t.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.SnapshotKetQua s ON s.MaDotBauCu = d.MaDotBauCu
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
    d.BlockDongBoGanNhat,
    s.ThoiGianSnapshot,
    s.UngCuVienChienThang,
    s.PhieuChienThang,
    s.TyLeChienThang;
GO

-- 7. Tạo view lịch sử bầu cử với snapshot
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
    s.UngCuVienChienThang AS Winner,
    s.PhieuChienThang AS WinnerVotes,
    s.TyLeChienThang AS WinnerPercentage,
    s.TongSoPhieu AS TotalVotes,
    s.TongSoCuTri AS TotalVoters,
    s.ThoiGianSnapshot AS SnapshotTime
FROM voting.DotBauCu d
LEFT JOIN voting.SnapshotKetQua s ON s.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.PhieuBau p ON p.MaDotBauCu = d.MaDotBauCu
LEFT JOIN voting.DanhSachTrang t ON t.MaDotBauCu = d.MaDotBauCu
GROUP BY
    d.MaDotBauCu,
    d.MaDotBauCuCu,
    d.TenDot,
    d.TrangThai,
    d.BatDauLucUtc,
    d.KetThucLucUtc,
    d.TaoLucUtc,
    s.UngCuVienChienThang,
    s.PhieuChienThang,
    s.TyLeChienThang,
    s.TongSoPhieu,
    s.TongSoCuTri,
    s.ThoiGianSnapshot;
GO

-- 8. Tạo view kết quả bầu cử chi tiết
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

-- 9. Tạo view danh sách cử tri đã bỏ phiếu
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

-- 10. Tạo view audit log
IF OBJECT_ID('voting.vwAuditLog', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwAuditLog;
END
GO

CREATE VIEW voting.vwAuditLog
AS
SELECT
    a.MaAuditLog,
    a.MaDotBauCuCu AS ElectionNumber,
    a.LoaiHanhDong AS ActionType,
    a.ThucThe AS EntityType,
    a.NoiDung AS Description,
    a.ThucHienBoi AS PerformedBy,
    a.ThoiGian AS Timestamp,
    a.DuLieuCu AS OldData,
    a.DuLieuMoi AS NewData
FROM voting.AuditLog a;
GO

-- 11. Tạo view thống kê tổng hợp
IF OBJECT_ID('voting.vwThongKeTongHop', 'V') IS NOT NULL
BEGIN
    DROP VIEW voting.vwThongKeTongHop;
END
GO

CREATE VIEW voting.vwThongKeTongHop
AS
SELECT
    TongSoDotBauCu AS TotalElections,
    TongSoCuTri AS TotalVoters,
    TongSoPhieu AS TotalVotes,
    CapNhatLucUtc AS LastUpdated
FROM voting.ThongKeTongHop;
GO

PRINT 'Đã tạo lại các views';
GO

PRINT 'Hoàn tất cải thiện cấu trúc database!';
GO
