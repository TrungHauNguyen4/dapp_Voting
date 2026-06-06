# CV - Dự án Decentralized Voting DApp

## Thông tin dự án

**Tên dự án:** Decentralized Voting DApp - Hệ thống Bầu cử Phi tập trung trên Blockchain

**Mô tả:** Hệ thống bầu cử minh bạch dựa trên blockchain Ethereum Sepolia, cho phép quản trị viên tổ chức nhiều kỳ bầu cử, cử tri whitelist bỏ phiếu an toàn, và đồng bộ dữ liệu về SQL Server để phục vụ báo cáo và kiểm toán.

**Thời gian thực hiện:** 2024

---

## Thành viên nhóm

| STT | MSSV | Họ tên | Vai trò | Nhiệm vụ chính |
|:---|:---|:---|:---|:---|
| 1 | 0023411914 | Nguyễn Trung Hậu | Team Leader & Full-stack Developer | Thiết kế và xây dựng toàn bộ hệ thống (Smart Contract, Frontend, Backend, Database, tích hợp MetaMask, Deploy), viết đặc tả hệ thống SRS |
| 2 | 0023411000 | Nguyễn Minh Huy | Thành viên | Đóng góp ý tưởng, test DApp |
| 3 | 0023411852 | Nguyễn Huyền Linh | Thành viên | Đóng góp ý tưởng, test DApp |
| 4 | 0023411981 | Nguyễn Phi Long | Thành viên | Đóng góp ý tưởng, test DApp |

---

## Kỹ thuật và Công nghệ sử dụng

### Smart Contract (Blockchain)
- **Ngôn ngữ:** Solidity ^0.8.20
- **Mạng:** Ethereum Sepolia Testnet
- **Mẫu thiết kế:** Multi-round voting (Single contract, multiple election rounds)
- **Thư viện:** ethers.js v6
- **Tính năng chính:**
  - Quản lý nhiều kỳ bầu cử trên cùng một contract
  - Whitelist cử tri với batch registration
  - Thêm ứng cử viên có hỗ trợ ảnh (URL hoặc base64)
  - Chống bỏ phiếu trùng (mapping voter address)
  - Event emissions cho off-chain synchronization
  - State machine: Created → Voting → Ended

### Frontend
- **Framework:** React 18.3.1 với TypeScript
- **Build Tool:** Vite 6.3.5
- **UI Libraries:**
  - Radix UI (Accordion, Dialog, Dropdown, Select, Tabs, v.v.)
  - Material UI (MUI) v7.3.5
  - Tailwind CSS v4.1.12
  - Lucide React (Icons)
  - Motion (Animations)
- **Tính năng chính:**
  - Kết nối ví MetaMask với auto-switch network
  - Giao diện Admin: tạo kỳ bầu cử, đăng ký whitelist, thêm ứng cử viên, bắt đầu/kết thúc bầu cử
  - Giao diện Cử tri: xem danh sách ứng cử viên, bỏ phiếu
  - Hiển thị kết quả thời gian thực với countdown timer
  - Tối ưu ảnh trước khi upload lên blockchain
  - Contract address locking để tránh nhầm lẫn môi trường

### Backend
- **Runtime:** Node.js với ES Modules
- **Framework:** Express 5.2.1
- **Database:** Microsoft SQL Server với driver mssql v12.2.1
- **CORS:** cors v2.8.6
- **API Endpoints:**
  - `GET /api/health` - Kiểm tra sức khỏe API và SQL Server
  - `GET /api/elections` - Lấy danh sách kỳ bầu cử từ SQL
  - `POST /api/sync` - Đồng bộ event từ blockchain về SQL
- **Tính năng đồng bộ:**
  - Query logs theo batch với auto-retry khi RPC timeout
  - Lưu trạng thái block đã quét để tránh quét lại
  - Đồng bộ events: VoterRegistered, VoteCast
  - Upsert dữ liệu election, candidates, votes, whitelist

### Database (SQL Server)
- **Database Name:** VotingDApp
- **Authentication:** SQL Authentication với driver mssql
- **Bảng dữ liệu (Tên tiếng Việt):**
  - `voting.DotBauCu` - Thông tin kỳ bầu cử (với ElectionIdOnChain và MaDotBauCuCu)
  - `voting.UngCuVien` - Danh sách ứng cử viên
  - `voting.DanhSachTrang` - Whitelist cử tri
  - `voting.PhieuBau` - Phiếu bầu
  - `voting.TrangThaiDongBo` - Trạng thái đồng bộ blockchain
  - `voting.SnapshotKetQua` - Snapshot kết quả bầu cử (chứng minh minh bạch)
  - `voting.AuditLog` - Log các thay đổi quan trọng
  - `voting.ThongKeTongHop` - Thống kê tổng hợp
- **Views:**
  - `voting.vwTongHopBauCu` - View tổng hợp dữ liệu bầu cử với snapshot
  - `voting.vwLichSuBauCu` - View lịch sử bầu cử với kết quả từ snapshot
  - `voting.vwKetQuaBauCu` - View kết quả bầu cử chi tiết
  - `voting.vwCuTriDaBau` - View danh sách cử tri đã bỏ phiếu
  - `voting.vwAuditLog` - View audit log
  - `voting.vwThongKeTongHop` - View thống kê tổng hợp
- **Setup Scripts:**
  - PowerShell setup script cho Windows/SQL Authentication
  - SQL scripts: create database, tables, views
  - Migration scripts: election ID columns, database optimization, structure improvement

### DevOps & Deployment
- **Package Manager:** npm với package-lock.json
- **Scripts:**
  - `npm run dev` - Chạy frontend với Vite
  - `npm run server` - Chạy backend Node.js
  - `npm run dev:full` - Chạy full stack (frontend + backend) với concurrently
  - `npm run sync` - Đồng bộ dữ liệu blockchain → SQL một lần
  - `npm run build` - Build production
- **Frontend Deployment:** Vercel (GitHub integration)
- **Cấu hình:**
  - `contract-config.json` - Cấu hình network, contract address, ABI, backend URL
  - `.env` - SQL Server credentials, CORS origins, host/port
  - Contract address locking mechanism với localStorage

---

## Các tính năng đã triển khai

### 1. Smart Contract (Voting.sol)
- ✅ Multi-round election system (single contract address)
- ✅ Admin-only functions với modifier `onlyAdmin`
- ✅ State machine với enum `State { Created, Voting, Ended }`
- ✅ Batch voter registration (`registerVoters`)
- ✅ Candidate management với image support (overload functions)
- ✅ Voting với anti-double-vote protection
- ✅ Event emissions: `ElectionCreated`, `VoterRegistered`, `CandidateAdded`, `ElectionStarted`, `VoteCast`, `ElectionEnded`
- ✅ Compatibility getters cho frontend cũ
- ✅ History helpers để query theo electionId cụ thể

### 2. Frontend (React + Vite)
- ✅ MetaMask wallet integration với ethers.js v6
- ✅ Auto-switch network sang Sepolia
- ✅ Contract address validation và locking
- ✅ Admin dashboard:
  - Tạo kỳ bầu cử mới
  - Đăng ký whitelist (single/batch)
  - Thêm ứng cử viên với URL ảnh hoặc file upload
  - Bắt đầu bầu cử với thời lượng tùy chỉnh
  - Kết thúc bầu cử khi hết thời gian
- ✅ Voter interface:
  - Xem danh sách ứng cử viên
  - Bỏ phiếu cho ứng cử viên
  - Xem trạng thái đã bỏ phiếu
- ✅ Real-time countdown timer
- ✅ Kết quả bầu cử với winner highlight
- ✅ Image optimization (resize, compress) trước khi upload
- ✅ Backend health check và sync button
- ✅ Auto-refresh mỗi 12 giây
- ✅ Responsive design với Tailwind CSS

### 3. Backend (Node.js + Express)
- ✅ REST API với CORS support
- ✅ SQL Server connection pooling
- ✅ Blockchain event synchronization:
  - Query logs theo batch với adaptive step size
  - Auto-retry khi RPC timeout
  - Lưu sync state để tránh quét lại
  - Lấy currentElectionId từ blockchain
- ✅ Database operations:
  - Upsert election metadata với Election ID calculation
  - Replace candidates
  - Upsert votes và whitelist
  - Tạo snapshot kết quả khi bầu cử kết thúc
  - Thêm audit log cho các thay đổi quan trọng
  - Cập nhật thống kê tổng hợp sau mỗi sync
- ✅ Election ID mechanism:
  - Tính MaDotBauCuCu = ElectionIdOnChain + MAX(MaDotBauCuCu)
  - Giải quyết vấn đề contract reset electionId khi deploy lại
- ✅ Error handling với meaningful messages

### 4. Database (SQL Server)
- ✅ Database schema với tên bảng/cột tiếng Việt
- ✅ Tables với proper indexes cho tối ưu hiệu suất
- ✅ Views cho aggregated queries
- ✅ Snapshot mechanism để chứng minh minh bạch
- ✅ Audit log để track lịch sử thay đổi
- ✅ Thống kê tổng hợp để tránh query phức tạp
- ✅ Election ID calculation mechanism
- ✅ PowerShell setup script
- ✅ Support cả Windows và SQL Authentication
- ✅ Migration scripts cho database evolution

### 5. Documentation & Configuration
- ✅ README.md với hướng dẫn chạy dự án
- ✅ SRS-VotingDApp.md - Đặc tả phần mềm chi tiết
- ✅ CONTRACT_REVIEW.md - Contract review document
- ✅ Database README với hướng dẫn setup
- ✅ coche.md - Document cơ chế tái sử dụng contract và cải tiến
- ✅ cv.md - CV dự án đầy đủ
- ✅ .env.example cho cấu hình môi trường
- ✅ contract-config.json cho network/contract configuration

---

## Quy trình triển khai

1. **Setup môi trường:**
   - Cài đặt dependencies: `npm install`
   - Cấu hình SQL Server trong `.env`
   - Chạy database setup script

2. **Deploy Smart Contract:**
   - Viết contract Voting.sol trên Remix IDE
   - Deploy lên Ethereum Sepolia
   - Copy ABI và contract address vào `contract-config.json`

3. **Chạy development:**
   - Frontend only: `npm run dev`
   - Full stack: `npm run dev:full`

4. **Đồng bộ dữ liệu:**
   - Manual sync: `npm run sync`
   - Hoặc qua API: `POST /api/sync`

5. **Production deployment:**
   - Build frontend: `npm run build`
   - Deploy backend lên VPS/Render/Railway
   - Cấu hình CORS origins trong `.env`
   - Cập nhật `backend.baseUrl` trong `contract-config.json`

---

## Thành tựu kỹ thuật

1. **Multi-round Architecture:** Thiết kế single contract hỗ trợ nhiều kỳ bầu cử, giảm chi phí deploy
2. **Event-driven Sync:** Sử dụng blockchain events để đồng bộ off-chain data hiệu quả
3. **Adaptive Batch Processing:** Tự động giảm batch size khi RPC timeout, đảm bảo sync ổn định
4. **Image Optimization:** Tối ưu ảnh client-side trước khi upload lên blockchain, tiết kiệm gas
5. **Contract Address Locking:** Cơ chế khóa contract address để tránh nhầm lẫn môi trường deploy
6. **Vietnamese Database Schema:** Sử dụng tên bảng/cột tiếng Việt cho dễ hiểu và phù hợp context
7. **Full-stack Integration:** Tích hợp seamless giữa smart contract, frontend, backend, và database
8. **Election ID Calculation:** Cơ chế tính MaDotBauCuCu = ElectionIdOnChain + MAX(MaDotBauCuCu) để giải quyết contract reset
9. **Snapshot Mechanism:** Tự động tạo snapshot kết quả khi bầu cử kết thúc để chứng minh minh bạch
10. **Audit Trail:** Tự động log các thay đổi quan trọng để track lịch sử
11. **Performance Optimization:** Thêm indexes và thống kê tổng hợp để tăng tốc độ query
12. **Database Evolution:** Migration scripts để nâng cấp database mà không mất dữ liệu

---

## Kinh nghiệm học được

- **Smart Contract Development:** State machine design, event emissions, gas optimization
- **Blockchain Integration:** ethers.js v6, MetaMask integration, RPC handling
- **Full-stack Development:** React, Express, SQL Server integration
- **Database Design:** Relational schema design cho blockchain data
- **DevOps:** Environment configuration, deployment strategies
- **Team Collaboration:** Agile development, code review, testing
