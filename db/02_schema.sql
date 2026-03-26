USE ClothingStoreDB;
GO

IF OBJECT_ID(N'dbo.Payments', N'U') IS NOT NULL DROP TABLE dbo.Payments;
IF OBJECT_ID(N'dbo.OrderDiscounts', N'U') IS NOT NULL DROP TABLE dbo.OrderDiscounts;
IF OBJECT_ID(N'dbo.OrderItems', N'U') IS NOT NULL DROP TABLE dbo.OrderItems;
IF OBJECT_ID(N'dbo.Orders', N'U') IS NOT NULL DROP TABLE dbo.Orders;
IF OBJECT_ID(N'dbo.DiscountCodes', N'U') IS NOT NULL DROP TABLE dbo.DiscountCodes;
IF OBJECT_ID(N'dbo.ProductReviews', N'U') IS NOT NULL DROP TABLE dbo.ProductReviews;
IF OBJECT_ID(N'dbo.ProductVariants', N'U') IS NOT NULL DROP TABLE dbo.ProductVariants;
IF OBJECT_ID(N'dbo.ProductImages', N'U') IS NOT NULL DROP TABLE dbo.ProductImages;
IF OBJECT_ID(N'dbo.Products', N'U') IS NOT NULL DROP TABLE dbo.Products;
IF OBJECT_ID(N'dbo.Users', N'U') IS NOT NULL DROP TABLE dbo.Users;
GO

CREATE TABLE dbo.Users (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    FullName NVARCHAR(120) NOT NULL,
    Email NVARCHAR(150) NOT NULL UNIQUE,
    Phone NVARCHAR(20) NULL,
    PasswordHash NVARCHAR(255) NULL,
    Role NVARCHAR(20) NOT NULL CHECK (Role IN ('customer','owner','admin')),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dbo.Products (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    OwnerId UNIQUEIDENTIFIER NULL,
    Name NVARCHAR(200) NOT NULL,
    Category NVARCHAR(80) NOT NULL,
    [Description] NVARCHAR(MAX) NULL,
    Price DECIMAL(18,2) NOT NULL CHECK (Price >= 0),
    DiscountPercent DECIMAL(5,2) NOT NULL DEFAULT 0 CHECK (DiscountPercent >= 0 AND DiscountPercent <= 100),
    Stock INT NOT NULL DEFAULT 0 CHECK (Stock >= 0),
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Products_Owner FOREIGN KEY (OwnerId) REFERENCES dbo.Users(Id)
);
GO

CREATE TABLE dbo.ProductImages (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    ProductId UNIQUEIDENTIFIER NOT NULL,
    ImageUrl NVARCHAR(500) NOT NULL,
    ColorHex NVARCHAR(10) NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    CONSTRAINT FK_ProductImages_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.ProductVariants (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    ProductId UNIQUEIDENTIFIER NOT NULL,
    SizeLabel NVARCHAR(10) NOT NULL,
    ColorHex NVARCHAR(10) NOT NULL,
    Stock INT NOT NULL DEFAULT 0 CHECK (Stock >= 0),
    CONSTRAINT FK_ProductVariants_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id) ON DELETE CASCADE,
    CONSTRAINT UQ_ProductVariants_Product_Size_Color UNIQUE (ProductId, SizeLabel, ColorHex)
);
GO

CREATE TABLE dbo.DiscountCodes (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    Code NVARCHAR(40) NOT NULL UNIQUE,
    [Percent] DECIMAL(5,2) NOT NULL CHECK ([Percent] > 0 AND [Percent] <= 100),
    MinOrderValue DECIMAL(18,2) NOT NULL DEFAULT 0 CHECK (MinOrderValue >= 0),
    StartDate DATETIME2 NOT NULL,
    EndDate DATETIME2 NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CONSTRAINT CK_DiscountCodes_DateRange CHECK (EndDate >= StartDate)
);
GO

CREATE TABLE dbo.Orders (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    OrderCode NVARCHAR(30) NOT NULL UNIQUE,
    UserId UNIQUEIDENTIFIER NOT NULL,
    ShippingAddress NVARCHAR(500) NOT NULL,
    PaymentMethod NVARCHAR(20) NOT NULL,
    PaymentStatus NVARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (PaymentStatus IN ('pending','paid','failed','cancelled')),
    [Status] NVARCHAR(20) NOT NULL DEFAULT 'processing' CHECK ([Status] IN ('processing','delivered','cancelled')),
    Subtotal DECIMAL(18,2) NOT NULL CHECK (Subtotal >= 0),
    DiscountAmount DECIMAL(18,2) NOT NULL DEFAULT 0 CHECK (DiscountAmount >= 0),
    Total DECIMAL(18,2) NOT NULL CHECK (Total >= 0),
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Orders_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id)
);
GO

CREATE TABLE dbo.OrderItems (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    OrderId UNIQUEIDENTIFIER NOT NULL,
    ProductId UNIQUEIDENTIFIER NOT NULL,
    SizeLabel NVARCHAR(10) NULL,
    ColorHex NVARCHAR(10) NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    UnitPrice DECIMAL(18,2) NOT NULL CHECK (UnitPrice >= 0),
    LineTotal DECIMAL(18,2) NOT NULL CHECK (LineTotal >= 0),
    CONSTRAINT FK_OrderItems_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id) ON DELETE CASCADE,
    CONSTRAINT FK_OrderItems_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id)
);
GO

CREATE TABLE dbo.OrderDiscounts (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    OrderId UNIQUEIDENTIFIER NOT NULL,
    DiscountId UNIQUEIDENTIFIER NOT NULL,
    Code NVARCHAR(40) NOT NULL,
    DiscountValue DECIMAL(18,2) NOT NULL CHECK (DiscountValue >= 0),
    CONSTRAINT FK_OrderDiscounts_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id) ON DELETE CASCADE,
    CONSTRAINT FK_OrderDiscounts_DiscountCodes FOREIGN KEY (DiscountId) REFERENCES dbo.DiscountCodes(Id)
);
GO

CREATE TABLE dbo.Payments (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    OrderId UNIQUEIDENTIFIER NOT NULL,
    Provider NVARCHAR(20) NOT NULL,
    ProviderTxnId NVARCHAR(100) NULL,
    Amount DECIMAL(18,2) NOT NULL CHECK (Amount >= 0),
    [Status] NVARCHAR(20) NOT NULL DEFAULT 'pending' CHECK ([Status] IN ('pending','paid','failed','cancelled')),
    RawResponse NVARCHAR(MAX) NULL,
    PaidAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Payments_Orders FOREIGN KEY (OrderId) REFERENCES dbo.Orders(Id) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.ProductReviews (
    Id UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
    ProductId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NOT NULL,
    Rating INT NOT NULL CHECK (Rating BETWEEN 1 AND 5),
    Comment NVARCHAR(1000) NULL,
    CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_ProductReviews_Products FOREIGN KEY (ProductId) REFERENCES dbo.Products(Id),
    CONSTRAINT FK_ProductReviews_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
    CONSTRAINT UQ_ProductReviews_Product_User UNIQUE (ProductId, UserId)
);
GO

CREATE INDEX IX_Users_Role ON dbo.Users(Role);
CREATE INDEX IX_Products_Category ON dbo.Products(Category);
CREATE INDEX IX_Orders_UserId ON dbo.Orders(UserId);
CREATE INDEX IX_Orders_Status ON dbo.Orders([Status]);
CREATE INDEX IX_Orders_PaymentStatus ON dbo.Orders(PaymentStatus);
CREATE INDEX IX_OrderItems_OrderId ON dbo.OrderItems(OrderId);
CREATE INDEX IX_Payments_OrderId ON dbo.Payments(OrderId);
CREATE INDEX IX_ProductReviews_ProductId ON dbo.ProductReviews(ProductId);
GO
