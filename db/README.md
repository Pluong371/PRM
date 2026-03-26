# SQL Server (SSMS) setup

Bạn đang dùng SQL Server Management Studio 20 thì chạy theo đúng thứ tự sau:

1. Mở SSMS, kết nối SQL Server.
2. Chạy file [01_create_database.sql](01_create_database.sql)
3. Chạy file [02_schema.sql](02_schema.sql)
4. Chạy file [03_seed.sql](03_seed.sql)

## Database name
- `ClothingStoreDB`

## Tài khoản seed sẵn
- Customer: `user@fashion.app`
- Owner: `owner@fashion.app`
- Admin: `admin@fashion.app`

## Gợi ý kiểm tra nhanh

```sql
USE ClothingStoreDB;
SELECT * FROM dbo.Users;
SELECT * FROM dbo.Products;
SELECT * FROM dbo.DiscountCodes;
```

## Bảng chính
- `Users`
- `Products`
- `ProductImages`
- `ProductVariants`
- `DiscountCodes`
- `Orders`
- `OrderItems`
- `OrderDiscounts`
- `Payments`

Schema đã có sẵn trường cho tích hợp VNPay backend:
- `Orders.PaymentStatus`
- `Payments.ProviderTxnId`
- `Payments.RawResponse`
