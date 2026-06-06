USE VotingDApp;
GO

DROP TABLE IF EXISTS voting.PhieuBau;
DROP TABLE IF EXISTS voting.DanhSachTrang;
DROP TABLE IF EXISTS voting.UngCuVien;
DROP TABLE IF EXISTS voting.TrangThaiDongBo;
DROP TABLE IF EXISTS voting.DotBauCu;
GO

CREATE TABLE voting.DotBauCu (
    MaDotBauCu UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),
    MaDotBauCuCu INT NOT NULL,
    ElectionIdOnChain INT NOT NULL,
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
    CONSTRAINT UQ_DotBauCu_HopDong_Mang UNIQUE (DiaChiHopDong, MaMang),
    CONSTRAINT UQ_DotBauCu_Cu UNIQUE (MaDotBauCuCu)
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
GO

-- Tạo bảng SnapshotKetQua - Lưu snapshot kết quả khi bầu cầu kết thúc
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

-- Tạo bảng AuditLog - Log các thay đổi quan trọng
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

-- Tạo bảng ThongKeTongHop - Thống kê tổng hợp
CREATE TABLE voting.ThongKeTongHop (
    MaThongKe BIGINT IDENTITY(1,1) NOT NULL,
    TongSoDotBauCu INT NOT NULL DEFAULT 0,
    TongSoCuTri INT NOT NULL DEFAULT 0,
    TongSoPhieu INT NOT NULL DEFAULT 0,
    CapNhatLucUtc DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_ThongKeTongHop PRIMARY KEY (MaThongKe)
);
GO

-- Thêm indexes cho các bảng hiện tại để tối ưu hiệu suất
CREATE INDEX IX_DotBauCu_MaDotBauCuCu ON voting.DotBauCu(MaDotBauCuCu);
CREATE INDEX IX_DotBauCu_TrangThai ON voting.DotBauCu(TrangThai);
CREATE INDEX IX_DotBauCu_TaoLucUtc ON voting.DotBauCu(TaoLucUtc DESC);
GO

CREATE INDEX IX_UngCuVien_SoPhieu ON voting.UngCuVien(SoPhieu DESC);
GO

CREATE INDEX IX_PhieuBau_SoKhoi ON voting.PhieuBau(SoKhoi DESC);
CREATE INDEX IX_PhieuBau_BauLucUtc ON voting.PhieuBau(BauLucUtc DESC);
GO

CREATE INDEX IX_DanhSachTrang_DangKyLucUtc ON voting.DanhSachTrang(DangKyLucUtc DESC);
GO
