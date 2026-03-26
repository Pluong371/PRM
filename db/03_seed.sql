USE ClothingStoreDB;
GO

SET NOCOUNT ON;

IF COL_LENGTH('dbo.ProductImages', 'ColorHex') IS NULL
BEGIN
  ALTER TABLE dbo.ProductImages ADD ColorHex NVARCHAR(10) NULL;
END;

IF COL_LENGTH('dbo.ProductVariants', 'ColorHex') IS NULL
BEGIN
  ALTER TABLE dbo.ProductVariants ADD ColorHex NVARCHAR(10) NULL;
END;

DECLARE @Customer1 UNIQUEIDENTIFIER = '11111111-1111-1111-1111-111111111111';
DECLARE @OwnerId   UNIQUEIDENTIFIER = '22222222-2222-2222-2222-222222222222';
DECLARE @AdminId   UNIQUEIDENTIFIER = '33333333-3333-3333-3333-333333333333';
DECLARE @Customer2 UNIQUEIDENTIFIER = '44444444-4444-4444-4444-444444444444';
DECLARE @Customer3 UNIQUEIDENTIFIER = '55555555-5555-5555-5555-555555555555';
DECLARE @Customer4 UNIQUEIDENTIFIER = '66666666-6666-6666-6666-666666666666';
DECLARE @Customer5 UNIQUEIDENTIFIER = '77777777-7777-7777-7777-777777777777';
DECLARE @Customer6 UNIQUEIDENTIFIER = '88888888-8888-8888-8888-888888888888';

DELETE FROM dbo.ProductReviews;
DELETE FROM dbo.Payments;
DELETE FROM dbo.OrderDiscounts;
DELETE FROM dbo.OrderItems;
DELETE FROM dbo.Orders;
DELETE FROM dbo.ProductVariants;
DELETE FROM dbo.ProductImages;
DELETE FROM dbo.DiscountCodes;
DELETE FROM dbo.Products;
DELETE FROM dbo.Users;

INSERT INTO dbo.Users(Id, FullName, Email, Phone, PasswordHash, Role, IsActive)
VALUES
(@Customer1, N'Nguyen An', 'user@fashion.app', '0901000001', '123456', 'customer', 1),
(@OwnerId,   N'Shop Owner', 'owner@fashion.app', '0901000002', '123456', 'owner', 1),
(@AdminId,   N'System Admin', 'admin@fashion.app', '0901000003', '123456', 'admin', 1),
(@Customer2, N'Tran Minh', 'minh@fashion.app', '0901000004', '123456', 'customer', 1),
(@Customer3, N'Le Thao', 'thao@fashion.app', '0901000005', '123456', 'customer', 1),
(@Customer4, N'Pham Kien', 'kien@fashion.app', '0901000006', '123456', 'customer', 1),
(@Customer5, N'Vo Nhi', 'nhi@fashion.app', '0901000007', '123456', 'customer', 1),
(@Customer6, N'Dang Long', 'long@fashion.app', '0901000008', '123456', 'customer', 1);

INSERT INTO dbo.DiscountCodes(Id, Code, [Percent], MinOrderValue, StartDate, EndDate, IsActive)
VALUES
('d0000000-0000-0000-0000-000000000001', 'SPRING10', 10, 500000, DATEADD(DAY, -15, SYSUTCDATETIME()), DATEADD(DAY, 60, SYSUTCDATETIME()), 1),
('d0000000-0000-0000-0000-000000000002', 'FREESTYLE15', 15, 1000000, DATEADD(DAY, -7, SYSUTCDATETIME()), DATEADD(DAY, 80, SYSUTCDATETIME()), 1),
('d0000000-0000-0000-0000-000000000003', 'NEWDROP5', 5, 300000, DATEADD(DAY, -2, SYSUTCDATETIME()), DATEADD(DAY, 40, SYSUTCDATETIME()), 1),
('d0000000-0000-0000-0000-000000000004', 'WEEKEND12', 12, 700000, DATEADD(DAY, -1, SYSUTCDATETIME()), DATEADD(DAY, 20, SYSUTCDATETIME()), 1),
('d0000000-0000-0000-0000-000000000005', 'VIP20', 20, 2000000, DATEADD(DAY, -5, SYSUTCDATETIME()), DATEADD(DAY, 30, SYSUTCDATETIME()), 1);

INSERT INTO dbo.Products(Id, Name, Category, [Description], Price, DiscountPercent, Stock, IsActive)
VALUES
('a0000000-0000-0000-0000-000000000001', N'Classic Denim Jacket', N'Men', N'Timeless denim jacket for daily layering.', 899000, 10, 0, 1),
('a0000000-0000-0000-0000-000000000002', N'Oversized Cotton Tee', N'Men', N'Breathable oversized t-shirt, easy to match.', 299000, 0, 0, 1),
('a0000000-0000-0000-0000-000000000003', N'Urban Cargo Pants', N'Men', N'Modern cargo fit with utility pockets.', 649000, 8, 0, 1),
('a0000000-0000-0000-0000-000000000004', N'Breeze Linen Shirt', N'Men', N'Lightweight linen shirt for warm weather.', 559000, 0, 0, 1),
('a0000000-0000-0000-0000-000000000005', N'Slim Chino Pants', N'Men', N'Clean silhouette chino for office and casual.', 599000, 5, 0, 1),

('a0000000-0000-0000-0000-000000000006', N'Minimal White Blouse', N'Women', N'Soft and elegant blouse for workwear.', 459000, 0, 0, 1),
('a0000000-0000-0000-0000-000000000007', N'Pleated Midi Skirt', N'Women', N'Flowy pleated skirt with premium texture.', 539000, 12, 0, 1),
('a0000000-0000-0000-0000-000000000008', N'Rib Knit Cardigan', N'Women', N'Layer-friendly cardigan with cozy knit fabric.', 629000, 10, 0, 1),
('a0000000-0000-0000-0000-000000000009', N'Satin Slip Dress', N'Women', N'Elegant satin dress for evening outings.', 799000, 0, 0, 1),
('a0000000-0000-0000-0000-000000000010', N'High-Waist Jeans', N'Women', N'Comfort stretch denim with flattering waistline.', 689000, 7, 0, 1),

('a0000000-0000-0000-0000-000000000011', N'Kids Graphic Tee', N'Kids', N'Soft cotton tee with playful graphics.', 229000, 0, 0, 1),
('a0000000-0000-0000-0000-000000000012', N'Kids Jogger Set', N'Kids', N'Comfortable jogger set for all-day wear.', 499000, 6, 0, 1),
('a0000000-0000-0000-0000-000000000013', N'Kids Hoodie', N'Kids', N'Warm hoodie with soft fleece lining.', 429000, 0, 0, 1),
('a0000000-0000-0000-0000-000000000014', N'Kids Party Dress', N'Kids', N'Cute party dress with layered skirt.', 579000, 10, 0, 1),
('a0000000-0000-0000-0000-000000000015', N'Kids Denim Shorts', N'Kids', N'Durable denim shorts for active days.', 319000, 0, 0, 1),

('a0000000-0000-0000-0000-000000000016', N'Street Runner Sneakers', N'Shoes', N'Everyday sneakers with cushioned sole.', 1099000, 15, 0, 1),
('a0000000-0000-0000-0000-000000000017', N'Canvas Low Tops', N'Shoes', N'Casual canvas shoes with clean design.', 799000, 10, 0, 1),
('a0000000-0000-0000-0000-000000000018', N'Chunky Sport Shoes', N'Shoes', N'Chunky silhouette for trendy street look.', 1299000, 18, 0, 1),

('a0000000-0000-0000-0000-000000000019', N'Neon Windbreaker', N'New Arrival', N'Lightweight windbreaker in vivid colorway.', 739000, 12, 0, 1),
('a0000000-0000-0000-0000-000000000020', N'Mono Varsity Jacket', N'Sale', N'Varsity jacket with premium embroidered patch.', 1199000, 25, 0, 1);

DECLARE @ImagePool TABLE (Idx INT IDENTITY(1,1) PRIMARY KEY, Url NVARCHAR(500));
INSERT INTO @ImagePool(Url)
VALUES
('https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=1000'),
('https://images.unsplash.com/photo-1483985988355-763728e1935b?w=1000'),
('https://images.unsplash.com/photo-1445205170230-053b83016050?w=1000'),
('https://images.unsplash.com/photo-1485968579580-b6d095142e6e?w=1000'),
('https://images.unsplash.com/photo-1512436991641-6745cdb1723f?w=1000'),
('https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=1000'),
('https://images.unsplash.com/photo-1541099649105-f69ad21f3246?w=1000'),
('https://images.unsplash.com/photo-1529139574466-a303027c1d8b?w=1000'),
('https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=1000'),
('https://images.unsplash.com/photo-1516257984-b1b4d707412e?w=1000'),
('https://images.unsplash.com/photo-1496747611176-843222e1e57c?w=1000'),
('https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=1000'),
('https://images.unsplash.com/photo-1514996937319-344454492b37?w=1000'),
('https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=1000'),
('https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=1000'),
('https://images.unsplash.com/photo-1530845641070-b5d6f42d5d2d?w=1000'),
('https://images.unsplash.com/photo-1506629905607-bb5b7f6ffb8e?w=1000'),
('https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=1000&sat=-20'),
('https://images.unsplash.com/photo-1492707892479-7bc8d5a4ee93?w=1000'),
('https://images.unsplash.com/photo-1503341455253-b2e723bb3dbb?w=1000');

;WITH P AS (
  SELECT Id, ROW_NUMBER() OVER (ORDER BY Name) AS rn
  FROM dbo.Products
)
INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
SELECT P.Id, I1.Url, '#000000', 1
FROM P
JOIN @ImagePool I1 ON I1.Idx = ((P.rn - 1) % 20) + 1
UNION ALL
SELECT P.Id, I2.Url, '#FFFFFF', 2
FROM P
JOIN @ImagePool I2 ON I2.Idx = ((P.rn + 6 - 1) % 20) + 1
UNION ALL
SELECT P.Id, I3.Url, '#1E88E5', 3
FROM P
JOIN @ImagePool I3 ON I3.Idx = ((P.rn + 12 - 1) % 20) + 1;

DECLARE @VariantTemplate TABLE(SizeLabel NVARCHAR(10), ColorHex NVARCHAR(10), BaseStock INT);
INSERT INTO @VariantTemplate(SizeLabel, ColorHex, BaseStock)
VALUES
('S', '#000000', 5),
('M', '#000000', 9),
('L', '#000000', 7),
('XL', '#000000', 4),
('S', '#FFFFFF', 3),
('M', '#FFFFFF', 6),
('L', '#FFFFFF', 5),
('XL', '#FFFFFF', 2);

;WITH P AS (
  SELECT Id, ROW_NUMBER() OVER (ORDER BY Name) AS rn
  FROM dbo.Products
)
INSERT INTO dbo.ProductVariants(Id, ProductId, SizeLabel, ColorHex, Stock)
SELECT NEWID(), P.Id, V.SizeLabel, V.ColorHex, V.BaseStock + ((P.rn + LEN(V.SizeLabel)) % 4)
FROM P
CROSS JOIN @VariantTemplate V;

UPDATE P
SET P.Stock = X.TotalStock
FROM dbo.Products P
JOIN (
  SELECT ProductId, SUM(Stock) AS TotalStock
  FROM dbo.ProductVariants
  GROUP BY ProductId
) X ON X.ProductId = P.Id;

INSERT INTO dbo.Orders(Id, OrderCode, UserId, ShippingAddress, PaymentMethod, PaymentStatus, [Status], Subtotal, DiscountAmount, Total)
VALUES
('b0000000-0000-0000-0000-000000000001', 'OD20260302001', @Customer1, N'123 Tran Hung Dao, Ho Chi Minh City', 'COD', 'paid', 'delivered', 1598000, 159800, 1438200),
('b0000000-0000-0000-0000-000000000002', 'OD20260302002', @Customer2, N'66 Le Loi, Da Nang', 'VNPay', 'paid', 'delivered', 1848000, 0, 1848000),
('b0000000-0000-0000-0000-000000000003', 'OD20260302003', @Customer3, N'12 Hai Ba Trung, Ha Noi', 'COD', 'pending', 'processing', 998000, 0, 998000),
('b0000000-0000-0000-0000-000000000004', 'OD20260302004', @Customer4, N'8 Nguyen Hue, Ho Chi Minh City', 'VNPay', 'paid', 'delivered', 2298000, 114900, 2183100),
('b0000000-0000-0000-0000-000000000005', 'OD20260302005', @Customer5, N'45 Vo Van Tan, Ho Chi Minh City', 'COD', 'cancelled', 'cancelled', 1199000, 0, 1199000),
('b0000000-0000-0000-0000-000000000006', 'OD20260302006', @Customer6, N'90 Tran Phu, Da Nang', 'VNPay', 'paid', 'delivered', 1388000, 0, 1388000),
('b0000000-0000-0000-0000-000000000007', 'OD20260302007', @Customer1, N'123 Tran Hung Dao, Ho Chi Minh City', 'COD', 'paid', 'processing', 858000, 0, 858000),
('b0000000-0000-0000-0000-000000000008', 'OD20260302008', @Customer2, N'66 Le Loi, Da Nang', 'VNPay', 'paid', 'delivered', 1698000, 169800, 1528200);

INSERT INTO dbo.OrderItems(Id, OrderId, ProductId, SizeLabel, ColorHex, Quantity, UnitPrice, LineTotal)
VALUES
(NEWID(), 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'M', '#000000', 1, 809100, 809100),
(NEWID(), 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000007', 'L', '#FFFFFF', 1, 474320, 474320),
(NEWID(), 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000011', 'S', '#1E88E5', 1, 229000, 229000),

(NEWID(), 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000016', '42', '#000000', 1, 934150, 934150),
(NEWID(), 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000003', 'L', '#FFFFFF', 1, 597080, 597080),
(NEWID(), 'b0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', 'M', '#000000', 1, 299000, 299000),

(NEWID(), 'b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000012', 'M', '#000000', 2, 469060, 938120),
(NEWID(), 'b0000000-0000-0000-0000-000000000003', 'a0000000-0000-0000-0000-000000000015', 'M', '#FFFFFF', 1, 319000, 319000),

(NEWID(), 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000018', '43', '#000000', 1, 1065180, 1065180),
(NEWID(), 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000009', 'M', '#FFFFFF', 1, 799000, 799000),
(NEWID(), 'b0000000-0000-0000-0000-000000000004', 'a0000000-0000-0000-0000-000000000014', 'S', '#1E88E5', 1, 521100, 521100),

(NEWID(), 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000020', 'L', '#000000', 1, 899250, 899250),
(NEWID(), 'b0000000-0000-0000-0000-000000000005', 'a0000000-0000-0000-0000-000000000017', '42', '#FFFFFF', 1, 719100, 719100),

(NEWID(), 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000010', 'M', '#000000', 1, 640770, 640770),
(NEWID(), 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000019', 'L', '#1E88E5', 1, 650320, 650320),
(NEWID(), 'b0000000-0000-0000-0000-000000000006', 'a0000000-0000-0000-0000-000000000013', 'M', '#FFFFFF', 1, 429000, 429000),

(NEWID(), 'b0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000008', 'M', '#000000', 1, 566100, 566100),
(NEWID(), 'b0000000-0000-0000-0000-000000000007', 'a0000000-0000-0000-0000-000000000004', 'L', '#FFFFFF', 1, 559000, 559000),

(NEWID(), 'b0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000006', 'M', '#FFFFFF', 2, 459000, 918000),
(NEWID(), 'b0000000-0000-0000-0000-000000000008', 'a0000000-0000-0000-0000-000000000001', 'L', '#000000', 1, 809100, 809100);

INSERT INTO dbo.OrderDiscounts(Id, OrderId, DiscountId, Code, DiscountValue)
VALUES
(NEWID(), 'b0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', 'SPRING10', 159800),
(NEWID(), 'b0000000-0000-0000-0000-000000000004', 'd0000000-0000-0000-0000-000000000004', 'WEEKEND12', 114900),
(NEWID(), 'b0000000-0000-0000-0000-000000000008', 'd0000000-0000-0000-0000-000000000001', 'SPRING10', 169800);

INSERT INTO dbo.Payments(Id, OrderId, Provider, ProviderTxnId, Amount, [Status], RawResponse, PaidAt)
VALUES
(NEWID(), 'b0000000-0000-0000-0000-000000000001', 'cod', 'COD-001', 1438200, 'paid', N'Cash on delivery confirmed', DATEADD(DAY, -8, SYSUTCDATETIME())),
(NEWID(), 'b0000000-0000-0000-0000-000000000002', 'vnpay', 'VNP-902001', 1848000, 'paid', N'Payment success', DATEADD(DAY, -7, SYSUTCDATETIME())),
(NEWID(), 'b0000000-0000-0000-0000-000000000003', 'cod', 'COD-003', 998000, 'pending', N'Waiting for shipping', NULL),
(NEWID(), 'b0000000-0000-0000-0000-000000000004', 'vnpay', 'VNP-902004', 2183100, 'paid', N'Payment success', DATEADD(DAY, -5, SYSUTCDATETIME())),
(NEWID(), 'b0000000-0000-0000-0000-000000000005', 'cod', 'COD-005', 1199000, 'cancelled', N'Order cancelled by user', NULL),
(NEWID(), 'b0000000-0000-0000-0000-000000000006', 'vnpay', 'VNP-902006', 1388000, 'paid', N'Payment success', DATEADD(DAY, -3, SYSUTCDATETIME())),
(NEWID(), 'b0000000-0000-0000-0000-000000000007', 'cod', 'COD-007', 858000, 'paid', N'Will collect on delivery', NULL),
(NEWID(), 'b0000000-0000-0000-0000-000000000008', 'vnpay', 'VNP-902008', 1528200, 'paid', N'Payment success', DATEADD(DAY, -1, SYSUTCDATETIME()));

INSERT INTO dbo.ProductReviews(Id, ProductId, UserId, Rating, Comment, CreatedAt, UpdatedAt)
VALUES
(NEWID(), 'a0000000-0000-0000-0000-000000000001', @Customer1, 5, N'Đường may đẹp, mặc lên form rất ổn.', DATEADD(DAY, -7, SYSUTCDATETIME()), DATEADD(DAY, -7, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000007', @Customer1, 4, N'Vải nhẹ, phù hợp đi làm.', DATEADD(DAY, -7, SYSUTCDATETIME()), DATEADD(DAY, -7, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000016', @Customer2, 5, N'Đi êm chân, phối đồ đẹp.', DATEADD(DAY, -6, SYSUTCDATETIME()), DATEADD(DAY, -6, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000003', @Customer2, 4, N'Chất liệu ổn trong tầm giá.', DATEADD(DAY, -6, SYSUTCDATETIME()), DATEADD(DAY, -6, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000012', @Customer3, 4, N'Bé nhà mình mặc rất vừa.', DATEADD(DAY, -4, SYSUTCDATETIME()), DATEADD(DAY, -4, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000018', @Customer4, 5, N'Mẫu chunky đúng trend, đáng mua.', DATEADD(DAY, -4, SYSUTCDATETIME()), DATEADD(DAY, -4, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000009', @Customer4, 4, N'Đầm đẹp, hơi dài nhẹ với mình.', DATEADD(DAY, -4, SYSUTCDATETIME()), DATEADD(DAY, -4, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000010', @Customer6, 5, N'Jeans ôm vừa, co giãn tốt.', DATEADD(DAY, -2, SYSUTCDATETIME()), DATEADD(DAY, -2, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000019', @Customer6, 4, N'Áo khoác nhẹ, màu nổi bật.', DATEADD(DAY, -2, SYSUTCDATETIME()), DATEADD(DAY, -2, SYSUTCDATETIME())),
(NEWID(), 'a0000000-0000-0000-0000-000000000006', @Customer2, 5, N'Form đẹp, mặc đi làm hợp.', DATEADD(DAY, -1, SYSUTCDATETIME()), DATEADD(DAY, -1, SYSUTCDATETIME()));

PRINT N'Seed completed: 8 users, 20 products, variants/images, discounts, orders, payments, reviews.';
GO
