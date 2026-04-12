
# Decentralized Voting DApp

Du an da duoc chuan bi de ban co the:
1. Viet va deploy contract tren Remix bang MetaMask.
2. Dan ABI + Contract Address vao cau hinh.
3. Chay ngay front-end ma khong can sua code logic.

## Chay du an

1. Cai thu vien:
`npm i`

2. Chay local:
`npm run dev`

3. Chay full stack (frontend + backend SQL):
`npm run dev:full`

4. Build production:
`npm run build`

## Trien khai de may khac co the vote

1. Deploy frontend len hosting tinh (Vercel/Netlify):
`npm run build`
2. Deploy backend len may chu/VPS/Render/Railway, sau do chay:
`npm run server`
3. Cap nhat [contract-config.json](contract-config.json):
	1. `backend.baseUrl = https://your-backend-domain`
	2. `contract.address` dung voi contract Sepolia da chot
	3. `contract.abi` dung voi contract da deploy
4. Cau hinh CORS backend trong `.env`:
	1. `CORS_ORIGINS=https://your-frontend-domain`
	2. Neu nhieu domain, tach boi dau phay
5. Dam bao nguoi dung:
	1. Dung MetaMask mang Sepolia
	2. Co SepoliaETH
	3. Da duoc whitelist tren contract

## Cau hinh backend SQL Server

1. Copy file `.env.example` thanh `.env`.
2. Dien thong tin SQL:
	1. `SQL_SERVER=MSI\\MSSQLSERVER01`
	2. `SQL_DATABASE=VotingDApp`
	3. `SQL_USER=...`
	4. `SQL_PASSWORD=...`
	5. `HOST=0.0.0.0`
	6. `PORT=4000`
	7. `CORS_ORIGINS=*` (dev) hoac `https://your-frontend-domain` (production)

Luu y: backend Node dang dung driver `mssql` voi SQL Authentication.

## Khoi tao database

Da co bo script san trong thu muc [database/](database/):
1. [database/01_create_database.sql](database/01_create_database.sql)
2. [database/02_create_tables.sql](database/02_create_tables.sql)
3. [database/03_views.sql](database/03_views.sql)

Chay nhanh:
`powershell -ExecutionPolicy Bypass -File .\\database\\setup.ps1 -ServerInstance "MSI\\MSSQLSERVER01"`

## Dong bo lich su tu blockchain vao SQL

Sau khi da deploy contract va cap nhat `contract-config.json`:
1. Dong bo 1 lan:
`npm run sync`
2. Hoac goi API:
`POST http://localhost:4000/api/sync`

API co san:
1. `GET /api/health`
2. `GET /api/elections`
3. `POST /api/sync`

## Cau hinh contract tu Remix

Sua file [contract-config.json](contract-config.json):
1. `network.chainId`
2. `network.chainName`
3. `network.rpcUrl`
4. `backend.baseUrl`
5. `contract.address`
6. `contract.abi`

Neu dung Sepolia, co the giu:
1. `chainId = 0xaa36a7`
2. `chainName = Sepolia Testnet`

## Co che khoa 1 contract duy nhat

Du an da bat che do khoa dia chi contract:
1. Lan dau chay, dia chi trong `contract-config.json` se duoc luu vao localStorage.
2. Nhung lan sau, neu doi sang dia chi khac, app se chan de tranh loi doi contract ngoai y muon.

Muc dich:
1. Dam bao toan bo he thong chi dung mot contract duy nhat sau khi chot deploy.
2. Khong bi tinh trang sua nham address khi deploy lai tren Remix.

## Neu bat buoc phai doi sang contract moi

Chi dung khi ban co chu y dinh thay contract (vi du reset he thong):
1. Mo DevTools Console.
2. Chay:
`localStorage.setItem('votingdapp.allowAddressOverride', 'true')`
3. Cap nhat `contract-config.json` voi address moi.
4. Reload trang 1 lan. He thong se khoa lai theo dia chi moi.

## Luu y quan trong ve Remix

Deploy thuong trong Remix se tao dia chi moi moi lan deploy. De giu 1 contract duy nhat:
1. Chot 1 lan deploy chinh thuc.
2. Khong deploy lai contract do.
3. Front-end chi tro vao dia chi da khoa trong `contract-config.json`.

Neu muon nang cap logic ma van giu nguyen dia chi, can dung Proxy pattern o phia smart contract.

## Checklist truoc khi demo

1. Contract da deploy thanh cong tren Sepolia.
2. `contract-config.json` da dien dung address + ABI + rpcUrl.
3. `.env` da dien SQL_USER va SQL_PASSWORD.
4. `npm run dev:full` chay thanh cong.
5. `POST /api/sync` tra ve ok=true.
6. `GET /api/elections` co du lieu ky bau cu.
  