USE VotingDApp;
GO

DROP TABLE IF EXISTS voting.PhieuBau;
DROP TABLE IF EXISTS voting.DanhSachTrang;
DROP TABLE IF EXISTS voting.UngCuVien;
DROP TABLE IF EXISTS voting.NhatKySuKien;
DROP TABLE IF EXISTS voting.TrangThaiDongBo;
DROP TABLE IF EXISTS voting.DotBauCu;
GO

CREATE TABLE voting.DotBauCu (
    MaDotBauCu UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    DiaChiHopDong NVARCHAR(42) NOT NULL,
    MaMang INT NOT NULL,
    DiaChiQuanTri NVARCHAR(42) NOT NULL,
    TenDot NVARCHAR(200) NULL,
    MoTa NVARCHAR(1000) NULL,
    TrangThai NVARCHAR(20) NOT NULL,
    BatDauLucUtc DATETIME2 NULL,
    KetThucLucUtc DATETIME2 NULL,
    TaoLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    BlockDongBoGanNhat BIGINT NULL,
    CONSTRAINT PK_DotBauCu PRIMARY KEY (MaDotBauCu),
    CONSTRAINT CK_DotBauCu_TrangThai CHECK (TrangThai IN ('Created', 'Voting', 'Ended')),
    CONSTRAINT UQ_DotBauCu_HopDong_Mang UNIQUE (DiaChiHopDong, MaMang)
);
GO

CREATE TABLE voting.UngCuVien (
    MaDongUngCuVien BIGINT IDENTITY(1,1) NOT NULL,
    MaDotBauCu UNIQUEIDENTIFIER NOT NULL,
    MaUngCuVien INT NOT NULL,
    TenUngCuVien NVARCHAR(200) NOT NULL,
    AnhUrl NVARCHAR(1000) NULL,
    SoPhieu BIGINT NOT NULL DEFAULT 0,
    TaoLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_UngCuVien PRIMARY KEY (MaDongUngCuVien),
    CONSTRAINT FK_UngCuVien_DotBauCu FOREIGN KEY (MaDotBauCu)
        REFERENCES voting.DotBauCu(MaDotBauCu) ON DELETE CASCADE,
    CONSTRAINT UQ_UngCuVien_Dot_Ma UNIQUE (MaDotBauCu, MaUngCuVien)
);
GO

CREATE TABLE voting.DanhSachTrang (
    MaTrang BIGINT IDENTITY(1,1) NOT NULL,
    MaDotBauCu UNIQUEIDENTIFIER NOT NULL,
    DiaChiVi NVARCHAR(42) NOT NULL,
    DangKyLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    DangKyBoi NVARCHAR(42) NULL,
    CONSTRAINT PK_DanhSachTrang PRIMARY KEY (MaTrang),
    CONSTRAINT FK_DanhSachTrang_DotBauCu FOREIGN KEY (MaDotBauCu)
        REFERENCES voting.DotBauCu(MaDotBauCu) ON DELETE CASCADE,
    CONSTRAINT UQ_DanhSachTrang_Dot_Vi UNIQUE (MaDotBauCu, DiaChiVi)
);
GO

CREATE TABLE voting.PhieuBau (
    MaPhieu BIGINT IDENTITY(1,1) NOT NULL,
    MaDotBauCu UNIQUEIDENTIFIER NOT NULL,
    DiaChiCuTri NVARCHAR(42) NOT NULL,
    MaUngCuVien INT NOT NULL,
    MaGiaoDich NVARCHAR(66) NOT NULL,
    SoKhoi BIGINT NOT NULL,
    BauLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_PhieuBau PRIMARY KEY (MaPhieu),
    CONSTRAINT FK_PhieuBau_DotBauCu FOREIGN KEY (MaDotBauCu)
        REFERENCES voting.DotBauCu(MaDotBauCu) ON DELETE CASCADE,
    CONSTRAINT FK_PhieuBau_UngCuVien FOREIGN KEY (MaDotBauCu, MaUngCuVien)
        REFERENCES voting.UngCuVien(MaDotBauCu, MaUngCuVien),
    CONSTRAINT UQ_PhieuBau_Dot_CuTri UNIQUE (MaDotBauCu, DiaChiCuTri),
    CONSTRAINT UQ_PhieuBau_MaGiaoDich UNIQUE (MaGiaoDich)
);
GO

CREATE TABLE voting.NhatKySuKien (
    MaNhatKy BIGINT IDENTITY(1,1) NOT NULL,
    MaDotBauCu UNIQUEIDENTIFIER NULL,
    DiaChiHopDong NVARCHAR(42) NOT NULL,
    MaMang INT NOT NULL,
    TenSuKien NVARCHAR(100) NOT NULL,
    MaGiaoDich NVARCHAR(66) NOT NULL,
    SoKhoi BIGINT NOT NULL,
    ChiSoLog INT NOT NULL,
    DuLieuJson NVARCHAR(MAX) NULL,
    TaoLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_NhatKySuKien PRIMARY KEY (MaNhatKy),
    CONSTRAINT UQ_NhatKySuKien_Khoi_Log UNIQUE (MaMang, SoKhoi, MaGiaoDich, ChiSoLog)
);
GO

CREATE TABLE voting.TrangThaiDongBo (
    MaTrangThai INT IDENTITY(1,1) NOT NULL,
    MaMang INT NOT NULL,
    DiaChiHopDong NVARCHAR(42) NOT NULL,
    KhoiDaQuet BIGINT NOT NULL,
    CapNhatLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_TrangThaiDongBo PRIMARY KEY (MaTrangThai),
    CONSTRAINT UQ_TrangThaiDongBo_Mang_HopDong UNIQUE (MaMang, DiaChiHopDong)
);
GO

CREATE INDEX IX_UngCuVien_MaDotBauCu ON voting.UngCuVien(MaDotBauCu);
CREATE INDEX IX_DanhSachTrang_MaDotBauCu ON voting.DanhSachTrang(MaDotBauCu);
CREATE INDEX IX_PhieuBau_MaDotBauCu ON voting.PhieuBau(MaDotBauCu);
CREATE INDEX IX_NhatKySuKien_HopDong_Khoi ON voting.NhatKySuKien(DiaChiHopDong, SoKhoi);
GO
