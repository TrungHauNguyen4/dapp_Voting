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
3. `03_views.sql`: Tao cac view tong hop va bao cao.
4. `05_add_election_id_columns.sql`: Migration script them cot ElectionIdOnChain va MaDotBauCuCu.
5. `06_optimize_database.sql`: Migration script toi uu database (xoa bang khong can, them view moi).
6. `07_improve_database_structure.sql`: Migration script cau truc moi cho minh bach va hieu suat.

## Cac bang chinh
1. `voting.DotBauCu`: Luu thong tin moi dot bau cu.
   - `MaDotBauCu`: GUID primary key
   - `MaDotBauCuCu`: INT ID tinh toan (ElectionIdOnChain + Max stored ID)
   - `ElectionIdOnChain`: INT ID tu blockchain (luon bat dau tu 1 khi deploy lai)
2. `voting.UngCuVien`: Luu danh sach ung cu vien theo dot.
3. `voting.DanhSachTrang`: Luu whitelist cu tri.
4. `voting.PhieuBau`: Luu phieu bau (moi vi 1 phieu/dot).
5. `voting.TrangThaiDongBo`: Luu block da quet de dong bo.
6. `voting.SnapshotKetQua`: Luu snapshot ket qua khi bau cu ket thuc (để chứng minh minh bach).
7. `voting.AuditLog`: Log cac thay doi quan trong (tao election, ket thuc, v.v.).
8. `voting.ThongKeTongHop`: Thong ke tong hop (tong so election, cu tri, phieu).

## Cac view bao cao
1. `voting.vwTongHopBauCu`: View tong hop thong tin bau cu (so ung cu vien, so phieu, so whitelist, snapshot).
2. `voting.vwLichSuBauCu`: View lich su cac cuoc bầu cử voi trang thai text va nguoi chien thang tu snapshot.
3. `voting.vwKetQuaBauCu`: View ket qua bau cử chi tiết (ty le phieu, danh dau nguoi chien thang).
4. `voting.vwCuTriDaBau`: View danh sach cử tri da bo phi.
5. `voting.vwAuditLog`: View audit log cac thay doi quan trong.
6. `voting.vwThongKeTongHop`: View thong ke tong hop.

## Cơ chế tính MaDotBauCuCu
Để giải quyết vấn đề contract luôn bắt đầu từ electionId = 1 khi deploy lại:
- Backend lấy `currentElectionId` từ blockchain
- Backend lấy `MAX(MaDotBauCuCu)` từ database
- Tính toán: `MaDotBauCuCu = ElectionIdOnChain + MAX(MaDotBauCuCu)`
- Ví dụ: Database có max ID = 5, contract tạo electionId = 1 → Database lưu 1 + 5 = 6

## Cơ chế Snapshot và Audit
- **SnapshotKetQua**: Tự động tạo snapshot khi bầu cử kết thúc, lưu kết quả cuối cùng để chứng minh minh bạch mà không cần query lại toàn bộ dữ liệu.
- **AuditLog**: Tự động log các thay đổi quan trọng (kết thúc bầu cử, thay đổi trạng thái) để track lịch sử.
- **ThongKeTongHop**: Tự động cập nhật thống kê tổng hợp sau mỗi sync để tránh query phức tạp.

## Migration cho database hiện có
Nếu database đã tồn tại trước khi thêm cơ chế mới:
```powershell
sqlcmd -S "MSI\MSSQLSERVER01" -d VotingDApp -i database\05_add_election_id_columns.sql
```

Để tối ưu database (xóa bảng không cần, thêm view mới):
```powershell
sqlcmd -S "MSI\MSSQLSERVER01" -d VotingDApp -i database\06_optimize_database.sql
```

Để cải thiện cấu trúc database cho minh bạch và hiệu suất:
```powershell
sqlcmd -S "MSI\MSSQLSERVER01" -d VotingDApp -i database\07_improve_database_structure.sql
```

## Luu y
1. Script se reset database, toan bo du lieu cu se bi xoa.
2. Database nay la off-chain analytics/audit.
3. Du lieu quyet dinh ket qua bau cu van nam tren smart contract.
4. Snapshot ket qua duoc tao tu dong khi bau cử ket thuc de chứng minh minh bach.
