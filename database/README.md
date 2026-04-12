# SQL Server Database Setup

## Muc tieu
Bo script nay tao database `VotingDApp` tren SQL Server de luu lich su bau cu off-chain.

## Yeu cau
1. SQL Server instance: `MSI\\MSSQLSERVER01`
2. Co `sqlcmd` trong PATH.
3. Co quyen tao database/schema/table.

## Chay nhanh (Windows Authentication)
```powershell
cd database
.\setup.ps1 -ServerInstance "MSI\MSSQLSERVER01"
```

## Chay bang SQL Authentication
```powershell
cd database
.\setup.ps1 -ServerInstance "MSI\MSSQLSERVER01" -UseSqlAuth -Username "sa" -Password "YOUR_PASSWORD"
```

## Cac file
1. `01_create_database.sql`: Tao database va schema `voting`.
2. `02_create_tables.sql`: Tao bang du lieu va indexes.
3. `03_views.sql`: Tao view tong hop `voting.vwElectionSummary`.

## Cac bang chinh
1. `voting.Elections`: Luu thong tin moi ky bau cu.
2. `voting.Candidates`: Luu danh sach ung cu vien theo ky.
3. `voting.Whitelist`: Luu whitelist cu tri.
4. `voting.Votes`: Luu vote records (moi vi 1 phieu/ky).
5. `voting.EventLogs`: Luu event on-chain da index.
6. `voting.SyncState`: Luu block da scan de dong bo.

## Luu y
1. Database nay la off-chain analytics/audit.
2. Du lieu quyet dinh ket qua bau cu van nam tren smart contract.
