import sqlDefault from "mssql";
import sqlNative from "mssql/msnodesqlv8.js";

let pool;
let sql = sqlDefault;

export async function getDbPool(sqlConfig) {
  if (pool) return pool;

  if (sqlConfig.driver === "msnodesqlv8") {
    sql = sqlNative;
    sqlConfig.options = {
      ...sqlConfig.options,
      trustedConnection: true
    };
  } else {
    sql = sqlDefault;
  }

  if (sqlConfig.connectionString) {
    pool = await sql.connect(sqlConfig.connectionString);
  } else {
    pool = await sql.connect(sqlConfig);
  }
  return pool;
}

export async function closeDbPool() {
  if (pool) {
    await pool.close();
    pool = null;
  }
}

export async function getMaxMaDotBauCuCu(pool) {
  const result = await pool.request().query(`
SELECT ISNULL(MAX(MaDotBauCuCu), 0) AS MaxId
FROM voting.DotBauCu
`);
  return Number(result.recordset[0].MaxId);
}

export async function upsertElection(pool, election) {
  const request = pool.request();
  request.input("ContractAddress", sql.NVarChar(42), election.contractAddress.toLowerCase());
  request.input("ChainId", sql.Int, election.chainId);
  request.input("AdminAddress", sql.NVarChar(42), election.adminAddress.toLowerCase());
  request.input("State", sql.NVarChar(20), election.state);
  request.input("StartTimeUtc", sql.DateTime2, election.startTimeUtc);
  request.input("EndTimeUtc", sql.DateTime2, election.endTimeUtc);
  request.input("ElectionIdOnChain", sql.Int, election.electionIdOnChain ?? 1);

  // Tính MaDotBauCuCu = ElectionIdOnChain + Max(MaDotBauCuCu hiện có)
  // Cơ chế này đảm bảo ID tăng dần ngay cả khi contract được deploy lại
  const maxStoredId = await getMaxMaDotBauCuCu(pool);
  const calculatedId = (election.electionIdOnChain ?? 1) + maxStoredId;
  request.input("MaDotBauCuCu", sql.Int, calculatedId);

  const query = `
MERGE voting.DotBauCu AS target
USING (SELECT @ContractAddress AS ContractAddress, @ChainId AS ChainId) AS source
ON target.DiaChiHopDong = source.ContractAddress AND target.MaMang = source.ChainId
WHEN MATCHED THEN
  UPDATE SET
    DiaChiQuanTri = @AdminAddress,
    TrangThai = @State,
    BatDauLucUtc = @StartTimeUtc,
    KetThucLucUtc = @EndTimeUtc,
    ElectionIdOnChain = @ElectionIdOnChain,
    MaDotBauCuCu = @MaDotBauCuCu
WHEN NOT MATCHED THEN
  INSERT (DiaChiHopDong, MaMang, DiaChiQuanTri, TrangThai, BatDauLucUtc, KetThucLucUtc, ElectionIdOnChain, MaDotBauCuCu)
  VALUES (@ContractAddress, @ChainId, @AdminAddress, @State, @StartTimeUtc, @EndTimeUtc, @ElectionIdOnChain, @MaDotBauCuCu)
OUTPUT inserted.MaDotBauCu;
`;

  const result = await request.query(query);
  return result.recordset[0].MaDotBauCu;
}

export async function replaceCandidates(pool, electionId, candidates) {
  for (const c of candidates) {
    await pool.request()
      .input("ElectionId", sql.UniqueIdentifier, electionId)
      .input("CandidateId", sql.Int, c.id)
      .input("CandidateName", sql.NVarChar(200), c.name)
      .input("ImageUrl", sql.NVarChar(1000), c.image || "")
      .input("VoteCount", sql.BigInt, c.voteCount)
      .query(`
MERGE voting.UngCuVien AS target
USING (
  SELECT
    @ElectionId AS MaDotBauCu,
    @CandidateId AS MaUngCuVien,
    @CandidateName AS TenUngCuVien,
    @ImageUrl AS AnhUrl,
    @VoteCount AS SoPhieu
) AS source
ON target.MaDotBauCu = source.MaDotBauCu AND target.MaUngCuVien = source.MaUngCuVien
WHEN MATCHED THEN
  UPDATE SET
    TenUngCuVien = source.TenUngCuVien,
    AnhUrl = source.AnhUrl,
    SoPhieu = source.SoPhieu
WHEN NOT MATCHED THEN
  INSERT (MaDotBauCu, MaUngCuVien, TenUngCuVien, AnhUrl, SoPhieu)
  VALUES (source.MaDotBauCu, source.MaUngCuVien, source.TenUngCuVien, source.AnhUrl, source.SoPhieu);
`);
  }
}

export async function upsertSyncState(pool, chainId, contractAddress, blockNumber) {
  const request = pool.request();
  request.input("ChainId", sql.Int, chainId);
  request.input("ContractAddress", sql.NVarChar(42), contractAddress.toLowerCase());
  request.input("LastScannedBlock", sql.BigInt, blockNumber);

  await request.query(`
MERGE voting.TrangThaiDongBo AS target
USING (SELECT @ChainId AS ChainId, @ContractAddress AS ContractAddress) AS source
ON target.MaMang = source.ChainId AND target.DiaChiHopDong = source.ContractAddress
WHEN MATCHED THEN
  UPDATE SET KhoiDaQuet = @LastScannedBlock, CapNhatLucUtc = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
  INSERT (MaMang, DiaChiHopDong, KhoiDaQuet)
  VALUES (@ChainId, @ContractAddress, @LastScannedBlock);
`);
}

export async function getSyncState(pool, chainId, contractAddress) {
  const result = await pool.request()
    .input("ChainId", sql.Int, chainId)
    .input("ContractAddress", sql.NVarChar(42), contractAddress.toLowerCase())
    .query(`
SELECT TOP 1 KhoiDaQuet
FROM voting.TrangThaiDongBo
WHERE MaMang = @ChainId AND DiaChiHopDong = @ContractAddress
`);

  if (result.recordset.length === 0) return null;
  return Number(result.recordset[0].KhoiDaQuet);
}

export async function upsertVote(pool, voteRow) {
  await pool.request()
    .input("ElectionId", sql.UniqueIdentifier, voteRow.electionId)
    .input("VoterAddress", sql.NVarChar(42), voteRow.voterAddress.toLowerCase())
    .input("CandidateId", sql.Int, voteRow.candidateId)
    .input("TransactionHash", sql.NVarChar(66), voteRow.transactionHash)
    .input("BlockNumber", sql.BigInt, voteRow.blockNumber)
    .query(`
BEGIN TRY
    INSERT INTO voting.PhieuBau (MaDotBauCu, DiaChiCuTri, MaUngCuVien, MaGiaoDich, SoKhoi)
    VALUES (@ElectionId, @VoterAddress, @CandidateId, @TransactionHash, @BlockNumber)
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
END CATCH
`);
}

export async function upsertWhitelist(pool, whitelistRow) {
  await pool.request()
    .input("ElectionId", sql.UniqueIdentifier, whitelistRow.electionId)
    .input("WalletAddress", sql.NVarChar(42), whitelistRow.walletAddress.toLowerCase())
    .input("RegisteredBy", sql.NVarChar(42), whitelistRow.registeredBy?.toLowerCase() || null)
    .query(`
BEGIN TRY
    INSERT INTO voting.DanhSachTrang (MaDotBauCu, DiaChiVi, DangKyBoi)
    VALUES (@ElectionId, @WalletAddress, @RegisteredBy)
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
END CATCH
`);
}

export async function getElectionSummaries(pool) {
  const result = await pool.request().query("SELECT * FROM voting.vwTongHopBauCu ORDER BY CreatedAtUtc DESC");
  return result.recordset;
}

export async function createSnapshot(pool, electionId, electionData) {
  const request = pool.request();
  request.input("ElectionId", sql.UniqueIdentifier, electionId);
  request.input("TongSoUngCuVien", sql.Int, electionData.totalCandidates);
  request.input("TongSoPhieu", sql.Int, electionData.totalVotes);
  request.input("TongSoCuTri", sql.Int, electionData.totalVoters);
  request.input("UngCuVienChienThang", sql.NVarChar(200), electionData.winner || null);
  request.input("PhieuChienThang", sql.Int, electionData.winnerVotes || null);
  request.input("TyLeChienThang", sql.Decimal(5, 2), electionData.winnerPercentage || null);
  request.input("TrangThaiCu", sql.NVarChar(20), electionData.state);
  request.input("BlockSnapshot", sql.BigInt, electionData.blockNumber);
  request.input("HashSnapshot", sql.NVarChar(66), electionData.snapshotHash || null);

  await request.query(`
MERGE voting.SnapshotKetQua AS target
USING (SELECT @ElectionId AS MaDotBauCu) AS source
ON target.MaDotBauCu = source.MaDotBauCu
WHEN MATCHED THEN
  UPDATE SET
    TongSoUngCuVien = @TongSoUngCuVien,
    TongSoPhieu = @TongSoPhieu,
    TongSoCuTri = @TongSoCuTri,
    UngCuVienChienThang = @UngCuVienChienThang,
    PhieuChienThang = @PhieuChienThang,
    TyLeChienThang = @TyLeChienThang,
    TrangThaiCu = @TrangThaiCu,
    BlockSnapshot = @BlockSnapshot,
    HashSnapshot = @HashSnapshot
WHEN NOT MATCHED THEN
  INSERT (MaDotBauCu, MaDotBauCuCu, TongSoUngCuVien, TongSoPhieu, TongSoCuTri, UngCuVienChienThang, PhieuChienThang, TyLeChienThang, TrangThaiCu, BlockSnapshot, HashSnapshot)
  SELECT 
    @ElectionId,
    (SELECT MaDotBauCuCu FROM voting.DotBauCu WHERE MaDotBauCu = @ElectionId),
    @TongSoUngCuVien,
    @TongSoPhieu,
    @TongSoCuTri,
    @UngCuVienChienThang,
    @PhieuChienThang,
    @TyLeChienThang,
    @TrangThaiCu,
    @BlockSnapshot,
    @HashSnapshot;
`);
}

export async function updateThongKeTongHop(pool) {
  await pool.request().query(`
UPDATE voting.ThongKeTongHop
SET 
  TongSoDotBauCu = (SELECT COUNT(*) FROM voting.DotBauCu),
  TongSoCuTri = (SELECT COUNT(DISTINCT DiaChiVi) FROM voting.DanhSachTrang),
  TongSoPhieu = (SELECT COUNT(*) FROM voting.PhieuBau),
  CapNhatLucUtc = SYSUTCDATETIME();
`);
}

export async function addAuditLog(pool, auditData) {
  const request = pool.request();
  request.input("MaDotBauCu", sql.UniqueIdentifier, auditData.electionId || null);
  request.input("MaDotBauCuCu", sql.Int, auditData.electionNumber || null);
  request.input("LoaiHanhDong", sql.NVarChar(50), auditData.actionType);
  request.input("ThucThe", sql.NVarChar(50), auditData.entityType);
  request.input("NoiDung", sql.NVarChar(1000), auditData.description || null);
  request.input("ThucHienBoi", sql.NVarChar(42), auditData.performedBy || null);
  request.input("DuLieuCu", sql.NVarChar(sql.MAX), auditData.oldData ? JSON.stringify(auditData.oldData) : null);
  request.input("DuLieuMoi", sql.NVarChar(sql.MAX), auditData.newData ? JSON.stringify(auditData.newData) : null);

  await request.query(`
INSERT INTO voting.AuditLog (MaDotBauCu, MaDotBauCuCu, LoaiHanhDong, ThucThe, NoiDung, ThucHienBoi, DuLieuCu, DuLieuMoi)
VALUES (@MaDotBauCu, @MaDotBauCuCu, @LoaiHanhDong, @ThucThe, @NoiDung, @ThucHienBoi, @DuLieuCu, @DuLieuMoi);
`);
}
