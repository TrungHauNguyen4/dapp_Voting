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

export async function upsertElection(pool, election) {
  const request = pool.request();
  request.input("ContractAddress", sql.NVarChar(42), election.contractAddress.toLowerCase());
  request.input("ChainId", sql.Int, election.chainId);
  request.input("AdminAddress", sql.NVarChar(42), election.adminAddress.toLowerCase());
  request.input("State", sql.NVarChar(20), election.state);
  request.input("StartTimeUtc", sql.DateTime2, election.startTimeUtc);
  request.input("EndTimeUtc", sql.DateTime2, election.endTimeUtc);

  const query = `
MERGE voting.DotBauCu AS target
USING (SELECT @ContractAddress AS ContractAddress, @ChainId AS ChainId) AS source
ON target.DiaChiHopDong = source.ContractAddress AND target.MaMang = source.ChainId
WHEN MATCHED THEN
  UPDATE SET
    DiaChiQuanTri = @AdminAddress,
    TrangThai = @State,
    BatDauLucUtc = @StartTimeUtc,
    KetThucLucUtc = @EndTimeUtc
WHEN NOT MATCHED THEN
  INSERT (DiaChiHopDong, MaMang, DiaChiQuanTri, TrangThai, BatDauLucUtc, KetThucLucUtc)
  VALUES (@ContractAddress, @ChainId, @AdminAddress, @State, @StartTimeUtc, @EndTimeUtc)
OUTPUT inserted.MaDotBauCu;
`;

  const result = await request.query(query);
  return result.recordset[0].MaDotBauCu;
}

export async function replaceCandidates(pool, electionId, candidates) {
  await pool.request()
    .input("ElectionId", sql.UniqueIdentifier, electionId)
    .query("DELETE FROM voting.UngCuVien WHERE MaDotBauCu = @ElectionId");

  for (const c of candidates) {
    await pool.request()
      .input("ElectionId", sql.UniqueIdentifier, electionId)
      .input("CandidateId", sql.Int, c.id)
      .input("CandidateName", sql.NVarChar(200), c.name)
      .input("ImageUrl", sql.NVarChar(1000), c.image || "")
      .input("VoteCount", sql.BigInt, c.voteCount)
      .query(`
INSERT INTO voting.UngCuVien (MaDotBauCu, MaUngCuVien, TenUngCuVien, AnhUrl, SoPhieu)
VALUES (@ElectionId, @CandidateId, @CandidateName, @ImageUrl, @VoteCount)
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

export async function insertEventLog(pool, logRow) {
  await pool.request()
    .input("ElectionId", sql.UniqueIdentifier, logRow.electionId)
    .input("ContractAddress", sql.NVarChar(42), logRow.contractAddress.toLowerCase())
    .input("ChainId", sql.Int, logRow.chainId)
    .input("EventName", sql.NVarChar(100), logRow.eventName)
    .input("TransactionHash", sql.NVarChar(66), logRow.transactionHash)
    .input("BlockNumber", sql.BigInt, logRow.blockNumber)
    .input("LogIndex", sql.Int, logRow.logIndex)
    .input("PayloadJson", sql.NVarChar(sql.MAX), JSON.stringify(logRow.payload || {}))
    .query(`
BEGIN TRY
    INSERT INTO voting.NhatKySuKien
    (MaDotBauCu, DiaChiHopDong, MaMang, TenSuKien, MaGiaoDich, SoKhoi, ChiSoLog, DuLieuJson)
    VALUES
    (@ElectionId, @ContractAddress, @ChainId, @EventName, @TransactionHash, @BlockNumber, @LogIndex, @PayloadJson)
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() NOT IN (2601, 2627) THROW;
END CATCH
`);
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
