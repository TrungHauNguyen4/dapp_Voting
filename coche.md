# Cơ chế Tái sử dụng một Hợp đồng cho Nhiều Cuộc Bầu cử

## Tổng quan

Hệ thống Voting DApp sử dụng kiến trúc **Multi-round Election** cho phép một smart contract duy nhất hỗ trợ nhiều đợt bầu cử khác nhau mà không cần deploy contract mới cho mỗi đợt.

---

## Cấu trúc Dữ liệu Core

### 1. Election ID Counter
```solidity
uint256 public currentElectionId;
```
- Biến đếm tăng dần theo thời gian
- Mỗi lần tạo đợt bầu cử mới, giá trị này tăng lên 1
- Đóng vai trò là primary key cho mỗi đợt bầu cử

### 2. Election Round Struct
```solidity
struct ElectionRound {
    State state;           // Trạng thái: Created, Voting, Ended
    uint256 startTime;    // Thời gian bắt đầu (timestamp)
    uint256 endTime;       // Thời gian kết thúc (timestamp)
    uint256 candidatesCount; // Số lượng ứng cử viên
    bool exists;           // Đánh dấu đợt bầu cử tồn tại
}
```

### 3. Nested Mappings theo ElectionId
```solidity
// electionId -> ElectionRound metadata
mapping(uint256 => ElectionRound) private elections;

// electionId -> candidateId -> Candidate data
mapping(uint256 => mapping(uint256 => Candidate)) private electionCandidates;

// electionId -> voterAddress -> isWhitelisted
mapping(uint256 => mapping(address => bool)) private electionWhitelist;

// electionId -> voterAddress -> hasVoted
mapping(uint256 => mapping(address => bool)) private electionVoted;
```

**Tại sao dùng nested mapping?**
- Mỗi `electionId` có không gian dữ liệu riêng biệt
- Dữ liệu của đợt bầu cử cũ không bị ghi đè bởi đợt mới
- Truy xuất nhanh theo O(1) complexity

---

## State Machine cho Mỗi Đợt

```solidity
enum State {
    Created,  // Đã tạo, chưa mở bỏ phiếu
    Voting,   // Đang trong thời gian bỏ phiếu
    Ended     // Đã kết thúc
}
```

**Vòng đời của một đợt bầu cử:**
1. **Created** - Admin tạo đợt mới, đăng ký whitelist, thêm ứng cử viên
2. **Voting** - Admin bắt đầu bầu cử, cử tri bỏ phiếu
3. **Ended** - Admin kết thúc bầu cử, hiển thị kết quả

---

## Hàm Tạo Đợt Bầu cử Mới

### Constructor - Tạo đợt đầu tiên
```solidity
constructor() {
    admin = msg.sender;
    _createNewElection();  // Tạo đợt bầu cử đầu tiên (ID = 1)
}
```

### Hàm tạo đợt tiếp theo
```solidity
function createElection() external onlyAdmin {
    require(elections[currentElectionId].state == State.Ended, 
            "Ky bau hien tai chua ket thuc");
    _createNewElection();
}
```

**Logic:**
- Chỉ admin mới có quyền tạo đợt mới
- Đợt hiện tại phải ở trạng thái `Ended` mới được tạo đợt mới
- Đảm bảo không có đợt bầu cử chồng chéo

### Hàm nội bộ tạo đợt mới
```solidity
function _createNewElection() private {
    currentElectionId += 1;  // Tăng ID
    elections[currentElectionId] = ElectionRound({
        state: State.Created,
        startTime: 0,
        endTime: 0,
        candidatesCount: 0,
        exists: true
    });
    emit ElectionCreated(currentElectionId, block.timestamp);
}
```

---

## Các Hàm Hoạt động theo ElectionId Hiện tại

Tất cả các hàm nghiệp vụ đều hoạt động trên `currentElectionId`:

### Đăng ký cử tri
```solidity
function registerVoter(address _voter) external onlyAdmin inState(State.Created) {
    electionWhitelist[currentElectionId][_voter] = true;
    emit VoterRegistered(_voter);
}
```

### Thêm ứng cử viên
```solidity
function addCandidate(string calldata _name, string calldata _image) 
    external onlyAdmin inState(State.Created) {
    elections[currentElectionId].candidatesCount += 1;
    electionCandidates[currentElectionId][elections[currentElectionId].candidatesCount] = 
        Candidate({...});
    emit CandidateAdded(...);
}
```

### Bỏ phiếu
```solidity
function vote(uint256 _candidateId) external inState(State.Voting) {
    require(electionWhitelist[currentElectionId][msg.sender], "Vi khong nam trong whitelist");
    require(!electionVoted[currentElectionId][msg.sender], "Ban da bo phieu");
    electionVoted[currentElectionId][msg.sender] = true;
    electionCandidates[currentElectionId][_candidateId].voteCount += 1;
    emit VoteCast(msg.sender, _candidateId);
}
```

---

## Hàm Helper cho Lịch sử

Contract cung cấp các hàm để truy xuất dữ liệu theo electionId cụ thể:

### Lấy metadata theo electionId
```solidity
function getElectionMeta(uint256 electionId) 
    external view returns (State state, uint256 startTime, uint256 endAt, uint256 totalCandidates) {
    ElectionRound storage round = elections[electionId];
    require(round.exists, "Ky bau cu khong ton tai");
    return (round.state, round.startTime, round.endTime, round.candidatesCount);
}
```

### Lấy ứng cử viên theo electionId
```solidity
function getAllCandidatesByElection(uint256 electionId) 
    external view returns (Candidate[] memory) {
    ElectionRound storage round = elections[electionId];
    require(round.exists, "Ky bau cu khong ton tai");
    // ... return candidates
}
```

### Kiểm tra whitelist theo electionId
```solidity
function isRegisteredInElection(uint256 electionId, address wallet) 
    external view returns (bool) {
    require(elections[electionId].exists, "Ky bau cu khong ton tai");
    return electionWhitelist[electionId][wallet];
}
```

---

## Event Emissions cho Tracking

```solidity
event ElectionCreated(uint256 indexed electionId, uint256 createdAt);
event VoterRegistered(address indexed voter);
event CandidateAdded(uint256 indexed candidateId, string name, string image);
event ElectionStarted(uint256 startTime, uint256 endTime);
event VoteCast(address indexed voter, uint256 indexed candidateId);
event ElectionEnded(uint256 endTime);
```

**Mục đích:**
- Backend có thể đồng bộ dữ liệu on-chain về off-chain
- Track lịch sử các đợt bầu cử
- Audit trail cho từng transaction

---

## Ưu điểm của Cơ chế này

### 1. Tiết kiệm Gas
- Không cần deploy contract mới cho mỗi đợt bầu cử
- Chỉ tốn gas cho các transaction nghiệp vụ (register, vote, v.v.)

### 2. Dữ liệu Tập trung
- Tất cả lịch sử bầu cử nằm ở một địa chỉ contract duy nhất
- Dễ quản lý và backup

### 3. Dễ Quản lý cho Frontend
- Chỉ cần lưu một contract address trong config
- Không cần cập nhật config khi tạo đợt bầu cử mới

### 4. History Tracking
- Có thể query dữ liệu của bất kỳ đợt bầu cử nào trong quá khứ
- Hỗ trợ báo cáo và audit

### 5. State Isolation
- Mỗi đợt bầu cử có state riêng biệt
- Dữ liệu đợt cũ không bị ảnh hưởng bởi đợt mới

---

## Quy trình Hoạt động

### Đợt bầu cử đầu tiên (ID = 1)
1. Contract được deploy → Constructor tạo đợt ID=1 (state: Created)
2. Admin đăng ký whitelist, thêm ứng cử viên
3. Admin gọi `startElection()` → state: Voting
4. Cử tri bỏ phiếu
5. Admin gọi `endElection()` → state: Ended

### Đợt bầu cử thứ hai (ID = 2)
1. Admin gọi `createElection()` → Tạo đợt ID=2 (state: Created)
2. Admin đăng ký whitelist mới, thêm ứng cử viên mới
3. Admin gọi `startElection()` → state: Voting
4. Cử tri bỏ phiếu
5. Admin gọi `endElection()` → state: Ended

### Lặp lại cho các đợt tiếp theo...

---

## Lưu ý Quan trọng

### 1. Không thể xóa đợt bầu cử
- Dữ liệu của các đợt cũ vẫn tồn tại trên blockchain
- Chỉ có thể tạo đợt mới, không thể xóa đợt cũ

### 2. Gas cost tăng dần
- Càng nhiều đợt bầu cử, contract storage càng lớn
- Tuy nhiên, impact là nhỏ vì mỗi mapping entry chỉ tốn ~20,000 gas

### 3. Frontend cần handle electionId
- Frontend cần hiển thị thông tin theo `currentElectionId`
- Nếu muốn xem lịch sử, cần gọi các hàm helper với electionId cụ thể

### 4. Backend sync cần track electionId
- Backend cần lưu `electionId` khi đồng bộ events
- Để phân loại dữ liệu theo từng đợt bầu cử

---

## Vấn đề về ElectionId Reset khi Deploy Lại

### Vấn đề tiềm ẩn
```solidity
constructor() {
    admin = msg.sender;
    _createNewElection();  // Luôn tạo electionId = 1
}
```

Khi deploy lại contract:
- Contract mới luôn bắt đầu từ `electionId = 1`
- Nếu contract cũ đã có electionId = 1, 2, 3... thì sẽ bị reset

### Cách Database xử lý
Database sử dụng `contractAddress + chainId` làm primary key:
```sql
MERGE voting.DotBauCu AS target
USING (SELECT @ContractAddress AS ContractAddress, @ChainId AS ChainId) AS source
ON target.DiaChiHopDong = source.ContractAddress AND target.MaMang = source.ChainId
```

**Kịch bản:**
1. **Deploy contract mới với address khác:** ✅ Tạo row mới, không bị lỗi
2. **Deploy lại contract cũ với address cũ:** ⚠️ UPDATE row hiện tại, có thể mất dữ liệu

### Cơ chế bảo vệ hiện tại
Frontend có contract address locking:
```javascript
function enforceSingleContract(address, lockConfig = {}) {
    const locked = localStorage.getItem(storageKey);
    if (locked && locked.toLowerCase() !== address.toLowerCase()) {
        throw new Error(`Hệ thống đang khóa tại contract ${locked}`);
    }
}
```

**Giới hạn:**
- Chỉ bảo vệ phía frontend
- Admin vẫn có thể deploy lại contract trên Remix
- Có thể bypass bằng override flag

### Vấn đề không được giải quyết
1. **ElectionId không được lưu vào database**
   - Contract: electionId = 1, 2, 3... (reset khi deploy)
   - Database: MaDotBauCu = GUID (không reset)
   - Không thể trace electionId blockchain → database

2. **Mất dữ liệu lịch sử nếu deploy lại**
   - Nếu deploy lại contract cũ, database sẽ bị UPDATE
   - Dữ liệu election cũ sẽ bị ghi đè

### Khuyến nghị cải thiện
1. **Lưu electionId vào database** ✅ ĐÃ TRIỂN KHAI
   - Thêm cột `ElectionIdOnChain` vào bảng `voting.DotBauCu`
   - Backend sync lưu electionId từ blockchain
   - Có thể detect khi contract bị reset

2. **Contract versioning**
   - Thêm `contractVersion` vào contract
   - Database lưu version để detect upgrade
   - Chỉ cho phép upgrade, không cho phép reset

3. **Backup dữ liệu trước khi deploy lại**
   - Export dữ liệu cũ ra file
   - Restore nếu cần thiết

---

## Giải pháp đã triển khai: Cơ chế Tính ID Database

### Vấn đề
Contract luôn bắt đầu từ `electionId = 1` khi deploy lại, gây conflict với database đã có dữ liệu.

### Giải pháp
Backend tính toán `MaDotBauCuCu` bằng công thức:
```
MaDotBauCuCu = ElectionIdOnChain + MAX(MaDotBauCuCu hiện có trong database)
```

### Ví dụ minh họa
- Database hiện tại có max ID = 5
- Contract deploy lại, tạo electionId = 1
- Backend sync: 1 + 5 = 6 → Lưu MaDotBauCuCu = 6
- Contract tạo electionId = 2 tiếp theo
- Backend sync: 2 + 5 = 7 → Lưu MaDotBauCuCu = 7

### Thay đổi trong Database Schema
```sql
-- Thêm 2 cột mới vào bảng voting.DotBauCu
ALTER TABLE voting.DotBauCu ADD ElectionIdOnChain INT NOT NULL;
ALTER TABLE voting.DotBauCu ADD MaDotBauCuCu INT NOT NULL;
ALTER TABLE voting.DotBauCu ADD CONSTRAINT UQ_DotBauCu_Cu UNIQUE (MaDotBauCuCu);
```

### Thay đổi trong Backend (db.js)
```javascript
// Hàm mới: Lấy max MaDotBauCuCu từ database
export async function getMaxMaDotBauCuCu(pool) {
  const result = await pool.request().query(`
SELECT ISNULL(MAX(MaDotBauCuCu), 0) AS MaxId
FROM voting.DotBauCu
`);
  return Number(result.recordset[0].MaxId);
}

// Hàm upsertElection cập nhật
export async function upsertElection(pool, election) {
  // ...
  const maxStoredId = await getMaxMaDotBauCuCu(pool);
  const calculatedId = (election.electionIdOnChain ?? 1) + maxStoredId;
  request.input("MaDotBauCuCu", sql.Int, calculatedId);
  // ...
}
```

### Thay đổi trong Backend (sync.js)
```javascript
// Lấy currentElectionId từ blockchain
const currentElectionIdOnChain = Number(await contract.currentElectionId());

// Truyền vào upsertElection
const electionId = await upsertElection(pool, {
    // ...
    electionIdOnChain: currentElectionIdOnChain
});
```

### Migration Script
File `database/05_add_election_id_columns.sql` được tạo để:
- Thêm cột ElectionIdOnChain và MaDotBauCuCu
- Thêm constraint UNIQUE cho MaDotBauCuCu
- Khởi tạo dữ liệu cho các record cũ (nếu có)

### Cách chạy migration
```powershell
sqlcmd -S "MSI\MSSQLSERVER01" -d VotingDApp -i database\05_add_election_id_columns.sql
```

### Lợi ích của giải pháp
1. **ID tăng dần liên tục:** Dù contract được deploy lại bao nhiêu lần, ID trong database vẫn tăng dần
2. **Không bị conflict:** Mỗi election có ID duy nhất trong database
3. **Dễ trace:** Có thể map ElectionIdOnChain từ blockchain về MaDotBauCuCu trong database
4. **Backward compatible:** Migration script xử lý dữ liệu cũ

### Lưu ý quan trọng
- Cần chạy migration script trước khi sync với contract mới
- Nếu database đã có dữ liệu, migration sẽ gán ID dựa trên ROW_NUMBER()
- MaDotBauCuCu là INT, có giới hạn 2,147,483,647 - đủ cho hầu hết trường hợp
