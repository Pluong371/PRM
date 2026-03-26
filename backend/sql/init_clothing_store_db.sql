/*
  Init script for ClothingStoreDB (SQL Server)
  Safe to run multiple times.
*/

IF DB_ID(N'ClothingStoreDB') IS NULL
BEGIN
  CREATE DATABASE ClothingStoreDB;
END;
GO

USE ClothingStoreDB;
GO

/* =========================
   Users
   ========================= */
IF OBJECT_ID(N'dbo.Users', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Users (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Users PRIMARY KEY DEFAULT NEWID(),
    FullName NVARCHAR(120) NOT NULL,
    Email NVARCHAR(150) NOT NULL,
    Phone NVARCHAR(20) NULL,
    PasswordHash NVARCHAR(255) NULL,
    Role NVARCHAR(20) NOT NULL CONSTRAINT DF_Users_Role DEFAULT N'customer',
    IsActive BIT NOT NULL CONSTRAINT DF_Users_IsActive DEFAULT 1,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Users_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Users_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Users_Email UNIQUE (Email),
    CONSTRAINT CK_Users_Role CHECK (LOWER(Role) IN (N'admin', N'customer', N'owner'))
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Users_Role_IsActive' AND object_id = OBJECT_ID(N'dbo.Users'))
BEGIN
  CREATE INDEX IX_Users_Role_IsActive ON dbo.Users(Role, IsActive);
END;
GO

/* =========================
   Categories
   ========================= */
IF OBJECT_ID(N'dbo.Categories', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Categories (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Categories PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(120) NOT NULL,
    [Description] NVARCHAR(500) NULL,
    ImageUrl NVARCHAR(500) NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT 1,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Categories_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Categories_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Categories_Name UNIQUE (Name)
  );
END;
GO

/* =========================
   Products
   ========================= */
IF OBJECT_ID(N'dbo.Products', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Products (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Products PRIMARY KEY DEFAULT NEWID(),
    OwnerId UNIQUEIDENTIFIER NULL,
    Name NVARCHAR(200) NOT NULL,
    Category NVARCHAR(80) NOT NULL,
    [Description] NVARCHAR(MAX) NULL,
    Price DECIMAL(18,2) NOT NULL CONSTRAINT DF_Products_Price DEFAULT 0,
    DiscountPercent DECIMAL(5,2) NOT NULL CONSTRAINT DF_Products_DiscountPercent DEFAULT 0,
    Stock INT NOT NULL CONSTRAINT DF_Products_Stock DEFAULT 0,
    IsActive BIT NOT NULL CONSTRAINT DF_Products_IsActive DEFAULT 1,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Products_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Products_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Products_Owner FOREIGN KEY (OwnerId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Products_Price CHECK (Price >= 0),
    CONSTRAINT CK_Products_Discount CHECK (DiscountPercent >= 0 AND DiscountPercent <= 100),
    CONSTRAINT CK_Products_Stock CHECK (Stock >= 0)
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Products_IsActive_CreatedAt' AND object_id = OBJECT_ID(N'dbo.Products'))
BEGIN
  CREATE INDEX IX_Products_IsActive_CreatedAt ON dbo.Products(IsActive, CreatedAt DESC);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Products_OwnerId_IsActive' AND object_id = OBJECT_ID(N'dbo.Products'))
BEGIN
  CREATE INDEX IX_Products_OwnerId_IsActive ON dbo.Products(OwnerId, IsActive);
END;
GO

/* =========================
   ProductImages
   ========================= */
IF OBJECT_ID(N'dbo.ProductImages', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.ProductImages (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ProductImages PRIMARY KEY DEFAULT NEWID(),
    ProductId UNIQUEIDENTIFIER NOT NULL,
    ImageUrl NVARCHAR(500) NOT NULL,
    ColorHex NVARCHAR(10) NULL,
    SortOrder INT NOT NULL CONSTRAINT DF_ProductImages_SortOrder DEFAULT 1,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ProductImages_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductImages_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT CK_ProductImages_SortOrder CHECK (SortOrder >= 0)
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ProductImages_ProductId_SortOrder' AND object_id = OBJECT_ID(N'dbo.ProductImages'))
BEGIN
  CREATE INDEX IX_ProductImages_ProductId_SortOrder ON dbo.ProductImages(ProductId, SortOrder, Id);
END;
GO

/* =========================
   ProductVariants
   ========================= */
IF OBJECT_ID(N'dbo.ProductVariants', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.ProductVariants (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ProductVariants PRIMARY KEY DEFAULT NEWID(),
    ProductId UNIQUEIDENTIFIER NOT NULL,
    SizeLabel NVARCHAR(10) NOT NULL,
    ColorHex NVARCHAR(10) NULL,
    Stock INT NOT NULL CONSTRAINT DF_ProductVariants_Stock DEFAULT 0,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ProductVariants_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ProductVariants_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductVariants_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT CK_ProductVariants_Stock CHECK (Stock >= 0)
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ProductVariants_Product_Size_Color' AND object_id = OBJECT_ID(N'dbo.ProductVariants'))
BEGIN
  CREATE INDEX IX_ProductVariants_Product_Size_Color ON dbo.ProductVariants(ProductId, SizeLabel, ColorHex);
END;
GO

/* =========================
   DiscountCodes
   ========================= */
IF OBJECT_ID(N'dbo.DiscountCodes', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.DiscountCodes (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_DiscountCodes PRIMARY KEY DEFAULT NEWID(),
    Code NVARCHAR(40) NOT NULL,
    [Percent] DECIMAL(5,2) NOT NULL,
    MinOrderValue DECIMAL(18,2) NOT NULL CONSTRAINT DF_DiscountCodes_MinOrderValue DEFAULT 0,
    StartDate DATETIME2(0) NOT NULL,
    EndDate DATETIME2(0) NOT NULL,
    IsActive BIT NOT NULL CONSTRAINT DF_DiscountCodes_IsActive DEFAULT 1,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DiscountCodes_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_DiscountCodes_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_DiscountCodes_Code UNIQUE (Code),
    CONSTRAINT CK_DiscountCodes_Percent CHECK ([Percent] >= 0 AND [Percent] <= 100),
    CONSTRAINT CK_DiscountCodes_DateRange CHECK (EndDate >= StartDate)
  );
END;
GO

/* =========================
   Orders
   ========================= */
IF OBJECT_ID(N'dbo.Orders', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.Orders (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Orders PRIMARY KEY DEFAULT NEWID(),
    OrderCode NVARCHAR(30) NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    ShippingAddress NVARCHAR(500) NOT NULL,
    PaymentMethod NVARCHAR(20) NOT NULL,
    PaymentStatus NVARCHAR(20) NOT NULL,
    [Status] NVARCHAR(20) NOT NULL,
    Subtotal DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_Subtotal DEFAULT 0,
    DiscountAmount DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_DiscountAmount DEFAULT 0,
    Total DECIMAL(18,2) NOT NULL CONSTRAINT DF_Orders_Total DEFAULT 0,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Orders_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Orders_OrderCode UNIQUE (OrderCode),
    CONSTRAINT FK_Orders_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_Orders_PaymentStatus CHECK (LOWER(PaymentStatus) IN (N'pending', N'paid', N'failed')),
    CONSTRAINT CK_Orders_Status CHECK (LOWER([Status]) IN (N'processing', N'delivered', N'cancelled')),
    CONSTRAINT CK_Orders_Subtotal CHECK (Subtotal >= 0),
    CONSTRAINT CK_Orders_DiscountAmount CHECK (DiscountAmount >= 0),
    CONSTRAINT CK_Orders_Total CHECK (Total >= 0)
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Orders_UserId_CreatedAt' AND object_id = OBJECT_ID(N'dbo.Orders'))
BEGIN
  CREATE INDEX IX_Orders_UserId_CreatedAt ON dbo.Orders(UserId, CreatedAt DESC);
END;
GO

/* =========================
   OrderItems
   ========================= */
IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.OrderItems (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_OrderItems PRIMARY KEY DEFAULT NEWID(),
    OrderId UNIQUEIDENTIFIER NOT NULL,
    ProductId UNIQUEIDENTIFIER NOT NULL,
    SizeLabel NVARCHAR(10) NOT NULL,
    ColorHex NVARCHAR(10) NULL,
    Quantity INT NOT NULL,
    UnitPrice DECIMAL(18,2) NOT NULL,
    LineTotal DECIMAL(18,2) NOT NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_OrderItems_CreatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id),
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT CK_OrderItems_Quantity CHECK (Quantity > 0),
    CONSTRAINT CK_OrderItems_UnitPrice CHECK (UnitPrice >= 0),
    CONSTRAINT CK_OrderItems_LineTotal CHECK (LineTotal >= 0)
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OrderItems_OrderId' AND object_id = OBJECT_ID(N'dbo.OrderItems'))
BEGIN
  CREATE INDEX IX_OrderItems_OrderId ON dbo.OrderItems(OrderId);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_OrderItems_ProductId' AND object_id = OBJECT_ID(N'dbo.OrderItems'))
BEGIN
  CREATE INDEX IX_OrderItems_ProductId ON dbo.OrderItems(ProductId);
END;
GO

/* =========================
   UserOTP
   ========================= */
IF OBJECT_ID(N'dbo.UserOTP', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.UserOTP (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_UserOTP PRIMARY KEY DEFAULT NEWID(),
    UserId UNIQUEIDENTIFIER NOT NULL,
    Email NVARCHAR(150) NOT NULL,
    OTPCode NVARCHAR(10) NOT NULL,
    Attempts INT NOT NULL CONSTRAINT DF_UserOTP_Attempts DEFAULT 0,
    MaxAttempts INT NOT NULL CONSTRAINT DF_UserOTP_MaxAttempts DEFAULT 3,
    IsVerified BIT NOT NULL CONSTRAINT DF_UserOTP_IsVerified DEFAULT 0,
    IsExpired BIT NOT NULL CONSTRAINT DF_UserOTP_IsExpired DEFAULT 0,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_UserOTP_CreatedAt DEFAULT SYSUTCDATETIME(),
    ExpiresAt DATETIME2(0) NOT NULL,
    VerifiedAt DATETIME2(0) NULL,
    CONSTRAINT FK_UserOTP_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id)
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_UserOTP_UserId' AND object_id = OBJECT_ID(N'dbo.UserOTP'))
BEGIN
  CREATE INDEX IX_UserOTP_UserId ON dbo.UserOTP(UserId);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_UserOTP_Email' AND object_id = OBJECT_ID(N'dbo.UserOTP'))
BEGIN
  CREATE INDEX IX_UserOTP_Email ON dbo.UserOTP(Email);
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_UserOTP_Code' AND object_id = OBJECT_ID(N'dbo.UserOTP'))
BEGIN
  CREATE INDEX IX_UserOTP_Code ON dbo.UserOTP(OTPCode);
END;
GO

/* =========================
   ProductReviews
   ========================= */
IF OBJECT_ID(N'dbo.ProductReviews', N'U') IS NULL
BEGIN
  CREATE TABLE dbo.ProductReviews (
    Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ProductReviews PRIMARY KEY DEFAULT NEWID(),
    ProductId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    Rating INT NOT NULL,
    Comment NVARCHAR(1000) NULL,
    CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ProductReviews_CreatedAt DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ProductReviews_UpdatedAt DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductReviews_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT FK_ProductReviews_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT CK_ProductReviews_Rating CHECK (Rating BETWEEN 1 AND 5),
    CONSTRAINT UQ_ProductReviews_Product_User UNIQUE (ProductId, UserId)
  );
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_ProductReviews_ProductId_CreatedAt' AND object_id = OBJECT_ID(N'dbo.ProductReviews'))
BEGIN
  CREATE INDEX IX_ProductReviews_ProductId_CreatedAt ON dbo.ProductReviews(ProductId, CreatedAt DESC);
END;
GO

/* =========================
   Seed admin account (optional)
   NOTE: PasswordHash must be bcrypt hash generated by backend style.
   ========================= */
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'admin@local.dev')
BEGIN
  INSERT INTO dbo.Users (FullName, Email, Phone, PasswordHash, Role, IsActive)
  VALUES (N'System Admin', N'admin@local.dev', NULL, NULL, N'admin', 1);
END;
GO

/* =========================
   Fake data for development
   ========================= */

/* Users */
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'owner1@local.dev')
BEGIN
  INSERT INTO dbo.Users (FullName, Email, Phone, PasswordHash, Role, IsActive)
  VALUES (N'Nguyen Van Owner', N'owner1@local.dev', N'0900000001', NULL, N'owner', 1);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'owner2@local.dev')
BEGIN
  INSERT INTO dbo.Users (FullName, Email, Phone, PasswordHash, Role, IsActive)
  VALUES (N'Tran Thi Owner', N'owner2@local.dev', N'0900000002', NULL, N'owner', 1);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'customer1@local.dev')
BEGIN
  INSERT INTO dbo.Users (FullName, Email, Phone, PasswordHash, Role, IsActive)
  VALUES (N'Le Minh Customer', N'customer1@local.dev', N'0900000011', NULL, N'customer', 1);
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = N'customer2@local.dev')
BEGIN
  INSERT INTO dbo.Users (FullName, Email, Phone, PasswordHash, Role, IsActive)
  VALUES (N'Pham Ha Customer', N'customer2@local.dev', N'0900000012', NULL, N'customer', 1);
END;
GO

/* Categories */
IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Ao thun')
BEGIN
  INSERT INTO dbo.Categories (Name, [Description], ImageUrl, IsActive)
  VALUES (
    N'Ao thun',
    N'Ao thun casual hang ngay',
    N'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800',
    1
  );
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Ao so mi')
BEGIN
  INSERT INTO dbo.Categories (Name, [Description], ImageUrl, IsActive)
  VALUES (
    N'Ao so mi',
    N'Ao so mi cong so lich su',
    N'https://images.unsplash.com/photo-1603252109303-2751441dd157?w=800',
    1
  );
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Quan jeans')
BEGIN
  INSERT INTO dbo.Categories (Name, [Description], ImageUrl, IsActive)
  VALUES (
    N'Quan jeans',
    N'Quan jeans form slim va regular',
    N'https://images.unsplash.com/photo-1542272604-787c3835535d?w=800',
    1
  );
END;
GO

/* Products */
DECLARE @Owner1Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Users WHERE Email = N'owner1@local.dev');
DECLARE @Owner2Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Users WHERE Email = N'owner2@local.dev');

IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Name = N'Ao thun basic trang' AND Category = N'Ao thun')
BEGIN
  INSERT INTO dbo.Products (Id, OwnerId, Name, Category, [Description], Price, DiscountPercent, Stock, IsActive)
  VALUES (
    NEWID(),
    @Owner1Id,
    N'Ao thun basic trang',
    N'Ao thun',
    N'Chat vai cotton, mac thoai mai, phu hop di hoc va di lam.',
    199000,
    10,
    35,
    1
  );
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Name = N'Ao so mi xanh navy' AND Category = N'Ao so mi')
BEGIN
  INSERT INTO dbo.Products (Id, OwnerId, Name, Category, [Description], Price, DiscountPercent, Stock, IsActive)
  VALUES (
    NEWID(),
    @Owner1Id,
    N'Ao so mi xanh navy',
    N'Ao so mi',
    N'Ao so mi slim fit, thich hop cho moi truong cong so.',
    359000,
    5,
    20,
    1
  );
END;

IF NOT EXISTS (SELECT 1 FROM dbo.Products WHERE Name = N'Quan jeans slim den' AND Category = N'Quan jeans')
BEGIN
  INSERT INTO dbo.Products (Id, OwnerId, Name, Category, [Description], Price, DiscountPercent, Stock, IsActive)
  VALUES (
    NEWID(),
    @Owner2Id,
    N'Quan jeans slim den',
    N'Quan jeans',
    N'Quan jeans co gian nhe, de phoi do va ton dang.',
    449000,
    12,
    30,
    1
  );
END;
GO

/* Product images */
DECLARE @P1 UNIQUEIDENTIFIER = (
  SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Ao thun basic trang' AND Category = N'Ao thun'
);
DECLARE @P2 UNIQUEIDENTIFIER = (
  SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Ao so mi xanh navy' AND Category = N'Ao so mi'
);
DECLARE @P3 UNIQUEIDENTIFIER = (
  SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Quan jeans slim den' AND Category = N'Quan jeans'
);

IF @P1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductImages WHERE ProductId = @P1)
BEGIN
  INSERT INTO dbo.ProductImages (ProductId, ImageUrl, ColorHex, SortOrder)
  VALUES
    (@P1, N'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800', N'#FFFFFF', 1),
    (@P1, N'https://images.unsplash.com/photo-1527719327859-c6ce80353573?w=800', N'#FFFFFF', 2);
END;

IF @P2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductImages WHERE ProductId = @P2)
BEGIN
  INSERT INTO dbo.ProductImages (ProductId, ImageUrl, ColorHex, SortOrder)
  VALUES
    (@P2, N'https://images.unsplash.com/photo-1603252109303-2751441dd157?w=800', N'#1F2A44', 1),
    (@P2, N'https://images.unsplash.com/photo-1596755094514-f87e34085b2c?w=800', N'#1F2A44', 2);
END;

IF @P3 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductImages WHERE ProductId = @P3)
BEGIN
  INSERT INTO dbo.ProductImages (ProductId, ImageUrl, ColorHex, SortOrder)
  VALUES
    (@P3, N'https://images.unsplash.com/photo-1542272604-787c3835535d?w=800', N'#111111', 1),
    (@P3, N'https://images.unsplash.com/photo-1473966968600-fa801b869a1a?w=800', N'#111111', 2);
END;
GO

/* Product variants */
DECLARE @P1v UNIQUEIDENTIFIER = (
  SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Ao thun basic trang' AND Category = N'Ao thun'
);
DECLARE @P2v UNIQUEIDENTIFIER = (
  SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Ao so mi xanh navy' AND Category = N'Ao so mi'
);
DECLARE @P3v UNIQUEIDENTIFIER = (
  SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Quan jeans slim den' AND Category = N'Quan jeans'
);

IF @P1v IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductVariants WHERE ProductId = @P1v)
BEGIN
  INSERT INTO dbo.ProductVariants (Id, ProductId, SizeLabel, ColorHex, Stock)
  VALUES
    (NEWID(), @P1v, N'S', N'#FFFFFF', 10),
    (NEWID(), @P1v, N'M', N'#FFFFFF', 15),
    (NEWID(), @P1v, N'L', N'#FFFFFF', 10);
END;

IF @P2v IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductVariants WHERE ProductId = @P2v)
BEGIN
  INSERT INTO dbo.ProductVariants (Id, ProductId, SizeLabel, ColorHex, Stock)
  VALUES
    (NEWID(), @P2v, N'M', N'#1F2A44', 8),
    (NEWID(), @P2v, N'L', N'#1F2A44', 7),
    (NEWID(), @P2v, N'XL', N'#1F2A44', 5);
END;

IF @P3v IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.ProductVariants WHERE ProductId = @P3v)
BEGIN
  INSERT INTO dbo.ProductVariants (Id, ProductId, SizeLabel, ColorHex, Stock)
  VALUES
    (NEWID(), @P3v, N'30', N'#111111', 10),
    (NEWID(), @P3v, N'31', N'#111111', 10),
    (NEWID(), @P3v, N'32', N'#111111', 10);
END;

UPDATE p
SET p.Stock = ISNULL(v.TotalStock, 0),
    p.UpdatedAt = SYSUTCDATETIME()
FROM dbo.Products p
LEFT JOIN (
  SELECT ProductId, SUM(Stock) AS TotalStock
  FROM dbo.ProductVariants
  GROUP BY ProductId
) v ON v.ProductId = p.Id
WHERE p.Name IN (N'Ao thun basic trang', N'Ao so mi xanh navy', N'Quan jeans slim den');
GO

/* Discount code */
IF NOT EXISTS (SELECT 1 FROM dbo.DiscountCodes WHERE Code = N'WELCOME10')
BEGIN
  INSERT INTO dbo.DiscountCodes (Id, Code, [Percent], MinOrderValue, StartDate, EndDate, IsActive)
  VALUES (
    NEWID(),
    N'WELCOME10',
    10,
    200000,
    DATEADD(DAY, -7, SYSUTCDATETIME()),
    DATEADD(DAY, 60, SYSUTCDATETIME()),
    1
  );
END;
GO

/* Orders + OrderItems */
DECLARE @Customer1Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Users WHERE Email = N'customer1@local.dev');
DECLARE @Customer2Id UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Users WHERE Email = N'customer2@local.dev');
DECLARE @ProdA UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Ao thun basic trang' AND Category = N'Ao thun');
DECLARE @ProdB UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Ao so mi xanh navy' AND Category = N'Ao so mi');
DECLARE @ProdC UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Quan jeans slim den' AND Category = N'Quan jeans');

IF @Customer1Id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderCode = N'ORD-FAKE-0001')
BEGIN
  DECLARE @Order1Id UNIQUEIDENTIFIER = NEWID();
  INSERT INTO dbo.Orders (
    Id, OrderCode, UserId, ShippingAddress, PaymentMethod, PaymentStatus, [Status],
    Subtotal, DiscountAmount, Total
  )
  VALUES (
    @Order1Id,
    N'ORD-FAKE-0001',
    @Customer1Id,
    N'123 Nguyen Trai, Quan 1, TP.HCM',
    N'cod',
    N'paid',
    N'delivered',
    648000,
    64800,
    583200
  );

  IF @ProdA IS NOT NULL
  BEGIN
    INSERT INTO dbo.OrderItems (Id, OrderId, ProductId, SizeLabel, ColorHex, Quantity, UnitPrice, LineTotal)
    VALUES (NEWID(), @Order1Id, @ProdA, N'M', N'#FFFFFF', 1, 199000, 199000);
  END;

  IF @ProdC IS NOT NULL
  BEGIN
    INSERT INTO dbo.OrderItems (Id, OrderId, ProductId, SizeLabel, ColorHex, Quantity, UnitPrice, LineTotal)
    VALUES (NEWID(), @Order1Id, @ProdC, N'31', N'#111111', 1, 449000, 449000);
  END;
END;

IF @Customer2Id IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Orders WHERE OrderCode = N'ORD-FAKE-0002')
BEGIN
  DECLARE @Order2Id UNIQUEIDENTIFIER = NEWID();
  INSERT INTO dbo.Orders (
    Id, OrderCode, UserId, ShippingAddress, PaymentMethod, PaymentStatus, [Status],
    Subtotal, DiscountAmount, Total
  )
  VALUES (
    @Order2Id,
    N'ORD-FAKE-0002',
    @Customer2Id,
    N'88 Le Loi, Hai Chau, Da Nang',
    N'banking',
    N'pending',
    N'processing',
    359000,
    0,
    359000
  );

  IF @ProdB IS NOT NULL
  BEGIN
    INSERT INTO dbo.OrderItems (Id, OrderId, ProductId, SizeLabel, ColorHex, Quantity, UnitPrice, LineTotal)
    VALUES (NEWID(), @Order2Id, @ProdB, N'L', N'#1F2A44', 1, 359000, 359000);
  END;
END;
GO

/* Product reviews */
DECLARE @ReviewCustomer UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Users WHERE Email = N'customer1@local.dev');
DECLARE @ReviewProduct UNIQUEIDENTIFIER = (SELECT TOP 1 Id FROM dbo.Products WHERE Name = N'Ao thun basic trang' AND Category = N'Ao thun');

IF @ReviewCustomer IS NOT NULL AND @ReviewProduct IS NOT NULL
   AND NOT EXISTS (
     SELECT 1
     FROM dbo.ProductReviews
     WHERE UserId = @ReviewCustomer AND ProductId = @ReviewProduct
   )
BEGIN
  INSERT INTO dbo.ProductReviews (Id, ProductId, UserId, Rating, Comment)
  VALUES (
    NEWID(),
    @ReviewProduct,
    @ReviewCustomer,
    5,
    N'San pham dep, chat vai tot, dong goi can than.'
  );
END;
GO
