# SQL Server Database Setup

## Muc tieu
Bo script nay tao lai database `VotingDApp` tren SQL Server de luu lich su bau cu off-chain voi ten bang/cot bang tieng Viet.

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
1. `01_create_database.sql`: Xoa database cu va tao moi `VotingDApp`.
2. `02_create_tables.sql`: Tao bang du lieu voi ten bang/cot tieng Viet va indexes.
3. `03_views.sql`: Tao view tong hop `voting.vwTongHopBauCu`.
4. `05_add_election_id_columns.sql`: Migration script them cot ElectionIdOnChain va MaDotBauCuCu.

## Cac bang chinh
1. `voting.DotBauCu`: Luu thong tin moi dot bau cu.
   - `MaDotBauCu`: GUID primary key
   - `MaDotBauCuCu`: INT ID tinh toan (ElectionIdOnChain + Max stored ID)
   - `ElectionIdOnChain`: INT ID tu blockchain (luon bat dau tu 1 khi deploy lai)
2. `voting.UngCuVien`: Luu danh sach ung cu vien theo dot.
3. `voting.DanhSachTrang`: Luu whitelist cu tri.
4. `voting.PhieuBau`: Luu phieu bau (moi vi 1 phieu/dot).
5. `voting.NhatKySuKien`: Luu event on-chain da index.
6. `voting.TrangThaiDongBo`: Luu block da quet de dong bo.

## Cơ chế tính MaDotBauCuCu
Để giải quyết vấn đề contract luôn bắt đầu từ electionId = 1 khi deploy lại:
- Backend lấy `currentElectionId` từ blockchain
- Backend lấy `MAX(MaDotBauCuCu)` từ database
- Tính toán: `MaDotBauCuCu = ElectionIdOnChain + MAX(MaDotBauCuCu)`
- Ví dụ: Database có max ID = 5, contract tạo electionId = 1 → Database lưu 1 + 5 = 6

## Migration cho database hiện có
Nếu database đã tồn tại trước khi thêm cơ chế mới:
```powershell
sqlcmd -S "MSI\MSSQLSERVER01" -d VotingDApp -i database\05_add_election_id_columns.sql
```

## Luu y
1. Script se reset database, toan bo du lieu cu se bi xoa.
2. Database nay la off-chain analytics/audit.
3. Du lieu quyet dinh ket qua bau cu van nam tren smart contract.
