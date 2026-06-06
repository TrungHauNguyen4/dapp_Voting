-- Migration script: Thêm cột ElectionIdOnChain và MaDotBauCuCu
-- Chạy script này nếu database đã tồn tại và cần thêm cột mới

USE VotingDApp;
GO

-- Kiểm tra xem cột đã tồn tại chưa, nếu chưa thì thêm
IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('voting.DotBauCu') AND name = 'ElectionIdOnChain'
)
BEGIN
    ALTER TABLE voting.DotBauCu ADD ElectionIdOnChain INT NULL;
    PRINT 'Đã thêm cột ElectionIdOnChain';
END
ELSE
BEGIN
    PRINT 'Cột ElectionIdOnChain đã tồn tại';
END
GO

IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE object_id = OBJECT_ID('voting.DotBauCu') AND name = 'MaDotBauCuCu'
)
BEGIN
    ALTER TABLE voting.DotBauCu ADD MaDotBauCuCu INT NULL;
    PRINT 'Đã thêm cột MaDotBauCuCu';
END
ELSE
BEGIN
    PRINT 'Cột MaDotBauCuCu đã tồn tại';
END
GO

-- Thêm constraint UNIQUE cho MaDotBauCuCu nếu chưa tồn tại
IF NOT EXISTS (
    SELECT * FROM sys.key_constraints 
    WHERE type = 'UQ' AND parent_object_id = OBJECT_ID('voting.DotBauCu') AND name = 'UQ_DotBauCu_Cu'
)
BEGIN
    ALTER TABLE voting.DotBauCu ADD CONSTRAINT UQ_DotBauCu_Cu UNIQUE (MaDotBauCuCu);
    PRINT 'Đã thêm constraint UQ_DotBauCu_Cu';
END
ELSE
BEGIN
    PRINT 'Constraint UQ_DotBauCu_Cu đã tồn tại';
END
GO

-- Khởi tạo dữ liệu cho các record cũ (nếu có)
-- Sử dụng ROW_NUMBER() để gán MaDotBauCuCu dựa trên thứ tự tạo
UPDATE voting.DotBauCu
SET MaDotBauCuCu = sub.NewId,
    ElectionIdOnChain = sub.NewId
FROM (
    SELECT MaDotBauCu, 
           ROW_NUMBER() OVER (ORDER BY TaoLucUtc) as NewId
    FROM voting.DotBauCu
    WHERE MaDotBauCuCu IS NULL OR ElectionIdOnChain IS NULL
) sub
WHERE voting.DotBauCu.MaDotBauCu = sub.MaDotBauCu;

PRINT 'Đã khởi tạo dữ liệu cho các record cũ';
GO
