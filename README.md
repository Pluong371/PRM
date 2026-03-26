# Clothing Store API (SQL Server)

Backend này kết nối trực tiếp SQL Server (`ClothingStoreDB`) để Flutter app đọc/ghi dữ liệu thật.

## 1) Chuẩn bị DB trong SSMS

Chạy lần lượt:
- `db/01_create_database.sql`
- `db/02_schema.sql`
- `db/03_seed.sql`

## 2) Cấu hình backend

```bash
cd backend
copy .env.example .env
```

Sửa file `.env` theo SQL Server của bạn:
- `DB_SERVER`
- `DB_PORT`
- `DB_NAME`
- `DB_USER`
- `DB_PASSWORD`

Để bật Virtual Try-On qua FASHN API, cấu hình thêm:
- `FASHN_API_KEY` (bắt buộc)
- `FASHN_API_BASE_URL` (mặc định `https://api.fashn.ai/v1`)

## 3) Chạy backend

```bash
npm.cmd install
npm.cmd run dev
```

### Nếu máy chưa có npm

`npm` đi kèm Node.js. Trên Windows, cài nhanh bằng 1 trong 2 cách:

```powershell
winget install OpenJS.NodeJS.LTS
```

hoặc

```powershell
choco install nodejs-lts -y
```

Sau khi cài xong, đóng/mở lại terminal rồi kiểm tra:

```powershell
node -v
npm.cmd -v
```

Rồi chạy lại backend:

```bash
npm.cmd install
npm.cmd run dev
```

### Nếu PowerShell báo lỗi `npm.ps1 cannot be loaded`

Đây là do Execution Policy, không phải lỗi Node. Có 2 cách:

1. Dùng `npm.cmd` như hướng dẫn trên (khuyến nghị, không cần đổi policy)
2. Hoặc mở policy cho user hiện tại:

```powershell
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
```

API mặc định: `http://localhost:3000/api`

## 4) Flutter app trỏ API

`lib/services/api_service.dart` đã tự chọn base URL:
- Android emulator: `http://10.0.2.2:3000/api`
- Windows/Web: `http://localhost:3000/api`

## Endpoints đã có
- `POST /api/auth/login`
- `GET/POST/PUT/DELETE /api/products`
- `GET/POST /api/discounts`
- `GET/POST/PUT/PATCH /api/users`
- `GET/POST/PATCH /api/orders`
- `POST /api/tryon/batch`
- `GET /api/health`

## Tài khoản demo mặc định
- `admin@fashion.app` / `123456` -> Admin
- `owner@fashion.app` / `123456` -> Owner
- `user@fashion.app` / `123456` -> Customer
