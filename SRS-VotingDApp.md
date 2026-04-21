# ĐẶC TẢ PHẦN MỀM DAPP BẦU CỬ PHI TẬP TRUNG

## 1. Giới thiệu
### 1.1 Mục đích
Tài liệu này mô tả các yêu cầu phần mềm của hệ thống Voting DApp, làm cơ sở cho phân tích, thiết kế, phát triển, kiểm thử, triển khai và bảo trì.

### 1.2 Phạm vi hệ thống
Hệ thống hỗ trợ tổ chức bầu cử trên blockchain Ethereum (Sepolia), cho phép quản trị viên tạo và điều hành đợt bầu cử, cho cử tri đã được whitelist bỏ phiếu, công khai kết quả theo thời gian thực, đồng thời đồng bộ dữ liệu sự kiện on-chain về SQL Server để phục vụ báo cáo/audit.

### 1.3 Đối tượng sử dụng tài liệu
- Nhóm phát triển smart contract, frontend, backend.
- Quản trị viên hệ thống bầu cử.
- Người vận hành backend và cơ sở dữ liệu.

### 1.4 Định nghĩa, từ viết tắt
- SRS: Software Requirements Specification.
- DApp: Decentralized Application.
- ABI: Application Binary Interface của smart contract.
- RPC: Remote Procedure Call endpoint để kết nối blockchain.
- FR: Functional Requirement.
- NFR: Non-functional Requirement.

## 2. Mô tả tổng quan
### 2.1 Góc nhìn sản phẩm
Hệ thống gồm 3 lớp chính:
- Smart contract `Voting.sol` chạy trên Ethereum Sepolia, là nguồn dữ liệu bầu cử chính thức.
- Ứng dụng web (React + Vite + ethers) để người dùng kết nối MetaMask, thêm ứng cử viên (admin), bỏ phiếu (voter) và xem kết quả.
- Backend Node.js (Express) + SQL Server để đồng bộ event on-chain và cung cấp API tổng hợp dữ liệu lịch sử bầu cử.

### 2.2 Các nhóm người dùng

| Người dùng | Mô tả |
| :--- | :--- |
| Quản trị viên (Admin) | Ví sở hữu quyền quản trị contract, tạo đợt bầu cử, đăng ký cử tri, thêm ứng cử viên, bắt đầu/kết thúc bầu cử |
| Cử tri (Whitelisted Voter) | Ví đã được đăng ký trong whitelist của đợt bầu cử hiện tại, được quyền bỏ 1 phiếu |
| Người xem (Viewer) | Người dùng truy cập giao diện để xem danh sách ứng cử viên và kết quả |
| Vận hành hệ thống | Theo dõi backend, chạy đồng bộ dữ liệu blockchain -> SQL, kiểm tra API |

### 2.3 Giả định và ràng buộc
- Người dùng sử dụng trình duyệt web có cài MetaMask.
- Mạng mặc định là Sepolia; người dùng cần SepoliaETH để gửi giao dịch.
- Ứng dụng frontend hoạt động dựa trên `contract-config.json` (địa chỉ contract, ABI, RPC URL).
- Chỉ một địa chỉ contract được khóa sử dụng trong frontend để tránh nhầm lẫn môi trường.
- SQL Server phải được cấu hình đúng để backend lưu dữ liệu đồng bộ.

## 3. Yêu cầu chức năng (Functional Requirements)
- FR-01: Quản lý đợt bầu cử. Hệ thống phải cho phép admin tạo đợt bầu cử mới sau khi đợt hiện tại đã kết thúc.
- FR-02: Quản lý cử tri whitelist. Hệ thống phải cho phép admin đăng ký một hoặc nhiều địa chỉ ví cử tri trong trạng thái khởi tạo đợt bầu cử.
- FR-03: Quản lý ứng cử viên. Hệ thống phải cho phép admin thêm ứng cử viên (tên và tùy chọn ảnh) trước khi bắt đầu bầu cử.
- FR-04: Bắt đầu bầu cử. Hệ thống phải cho phép admin mở bỏ phiếu với thời lượng xác định (giây), chỉ khi có ít nhất một ứng cử viên.
- FR-05: Kết thúc bầu cử. Hệ thống phải cho phép admin kết thúc đợt bầu cử khi đã qua thời gian kết thúc.
- FR-06: Bỏ phiếu. Hệ thống phải cho phép cử tri whitelist bỏ phiếu cho một ứng cử viên hợp lệ trong thời gian bầu cử.
- FR-07: Chống bỏ phiếu trùng. Hệ thống phải từ chối mọi giao dịch bỏ phiếu của ví đã bỏ phiếu trong cùng đợt.
- FR-08: Tra cứu dữ liệu bầu cử hiện tại. Hệ thống phải cung cấp danh sách ứng cử viên, số phiếu, trạng thái đợt bầu cử và người thắng cuộc từ smart contract.
- FR-09: Kết nối ví. Frontend phải cho phép người dùng kết nối MetaMask và nhận diện quyền admin/cử tri theo địa chỉ ví.
- FR-10: Đồng bộ event blockchain. Backend phải đọc event `VoterRegistered`, `VoteCast` theo block range và lưu vào SQL Server.
- FR-11: API hệ thống. Backend phải cung cấp tối thiểu các API `/api/health`, `/api/elections`, `/api/sync`.
- FR-12: Lưu trạng thái đồng bộ. Hệ thống phải lưu block đã quét cuối cùng để lần đồng bộ sau chỉ quét phần block mới.

## 4. Yêu cầu phi chức năng (Non-functional Requirements)
- NFR-01: Toàn vẹn dữ liệu. Kết quả bầu cử chính thức phải lấy từ smart contract; dữ liệu SQL chỉ phục vụ truy vấn tổng hợp/audit.
- NFR-02: Bảo mật quyền hạn. Các thao tác quản trị phải được ràng buộc bởi địa chỉ admin ở mức smart contract.
- NFR-03: Tính minh bạch. Mọi giao dịch bầu cử phải truy vết được qua transaction hash và event log.
- NFR-04: Hiệu năng đồng bộ. Backend phải hỗ trợ truy vấn log theo batch và tự giảm kích thước batch khi RPC timeout.
- NFR-05: Khả năng mở rộng. Thiết kế phải hỗ trợ nhiều đợt bầu cử trên cùng một địa chỉ contract (multi-round).
- NFR-06: Tính khả dụng. Frontend phải hoạt động trên các trình duyệt hiện đại và hiển thị tốt trên desktop/mobile.
- NFR-07: Khả năng cấu hình. Các thông tin mạng, contract, CORS, SQL phải thay đổi được qua tệp cấu hình và biến môi trường mà không cần sửa logic nghiệp vụ.

## 5. Quy tắc nghiệp vụ (Business Rules)
- BR-01: Chỉ admin mới được tạo đợt bầu cử mới, đăng ký cử tri, thêm ứng cử viên, bắt đầu và kết thúc bầu cử.
- BR-02: Mỗi đợt bầu cử có vòng đời trạng thái: `Created -> Voting -> Ended`.
- BR-03: Chỉ cử tri nằm trong whitelist của đợt hiện tại mới được bỏ phiếu.
- BR-04: Mỗi địa chỉ ví chỉ được bỏ phiếu tối đa 1 lần trong mỗi đợt bầu cử.
- BR-05: Chỉ bỏ phiếu cho ứng cử viên có ID hợp lệ trong danh sách hiện tại.
- BR-06: Bầu cử chỉ kết thúc khi đạt/qua `endTime` đã thiết lập lúc bắt đầu.
- BR-07: Chỉ được mở đợt bầu cử mới sau khi đợt trước đã ở trạng thái `Ended`.
- BR-08: Mặc định người thắng là ứng cử viên có số phiếu cao nhất; nếu chưa có phiếu hợp lệ thì trạng thái thắng hiển thị là chưa có ai.

## Danh Sách Thành Viên

| STT | MSSV | Họ tên | Nhiệm vụ |
| :--- | :--- | :--- | :--- |
| 1 | 0023411914 | Nguyễn Trung Hậu | Thiết kế xây dựng: Dapp (front-backend, database, contract, kết nối ví MetaMask, deploy), viết đặc tả hệ thống |
| 2 | 0023411000 | Nguyễn Minh Huy | Đóng góp, lên ý tưởng, test dapp |
| 3 | 0023411852 | Nguyễn Huyền Linh | Đóng góp, lên ý tưởng, test dapp |
| 4 | 0023411981 | Nguyễn Phi Long | Đóng góp, lên ý tưởng, test dapp |
