require("dotenv").config();
const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const bcrypt = require("bcryptjs");
const { sql, getPool, ensureOtpTable } = require("./db");
const EmailService = require("./email_service");

const app = express();
app.use(cors());
app.use(express.json());

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || "clothing-store-dev-secret";
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || "7d";

function issueToken(user) {
  return jwt.sign(
    {
      sub: user.Id,
      role: user.Role,
      email: user.Email,
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN },
  );
}

function getBearerToken(req) {
  const authHeader = String(req.headers.authorization || "");
  if (!authHeader.toLowerCase().startsWith("bearer ")) return null;
  return authHeader.slice(7).trim();
}

function getTokenPayload(req) {
  const token = getBearerToken(req);
  if (!token) return null;
  try {
    return jwt.verify(token, JWT_SECRET);
  } catch (_error) {
    return null;
  }
}

function requireAuth(req, res, next) {
  const payload = getTokenPayload(req);
  if (!payload) {
    return res.status(401).json({ message: "Unauthorized" });
  }
  req.user = payload;
  return next();
}

function requireAdmin(req, res, next) {
  const payload = req.user || getTokenPayload(req);
  const role = String(payload?.role || "")
    .trim()
    .toLowerCase();
  if (!payload) {
    return res.status(401).json({ message: "Unauthorized" });
  }
  if (role !== "admin") {
    return res.status(403).json({ message: "Forbidden" });
  }
  req.user = payload;
  return next();
}

async function ensureProductReviewsTable() {
  const pool = await getPool();
  await pool.request().query(
    `IF OBJECT_ID('dbo.ProductReviews', 'U') IS NULL
     BEGIN
       CREATE TABLE dbo.ProductReviews (
         Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ProductReviews PRIMARY KEY,
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
     END`,
  );
}

async function ensureReviewHelpfulVotesTable() {
  const pool = await getPool();
  await pool.request().query(
    `IF OBJECT_ID('dbo.ReviewHelpfulVotes', 'U') IS NULL
     BEGIN
       CREATE TABLE dbo.ReviewHelpfulVotes (
         Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_ReviewHelpfulVotes PRIMARY KEY,
         ReviewId UNIQUEIDENTIFIER NOT NULL,
         UserId UNIQUEIDENTIFIER NOT NULL,
         CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_ReviewHelpfulVotes_CreatedAt DEFAULT SYSUTCDATETIME(),
         CONSTRAINT FK_ReviewHelpfulVotes_Review FOREIGN KEY (ReviewId) REFERENCES dbo.ProductReviews(Id),
         CONSTRAINT FK_ReviewHelpfulVotes_User FOREIGN KEY (UserId) REFERENCES dbo.Users(Id),
         CONSTRAINT UQ_ReviewHelpfulVotes_Review_User UNIQUE (ReviewId, UserId)
       );
     END`,
  );
}

async function ensureNotificationsTable() {
  const pool = await getPool();
  await pool.request().query(
    `IF OBJECT_ID('dbo.UserNotifications', 'U') IS NULL
     BEGIN
       CREATE TABLE dbo.UserNotifications (
         Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_UserNotifications PRIMARY KEY,
         UserId UNIQUEIDENTIFIER NOT NULL,
         [Type] NVARCHAR(50) NOT NULL,
         Title NVARCHAR(150) NOT NULL,
         [Message] NVARCHAR(500) NOT NULL,
         RefId UNIQUEIDENTIFIER NULL,
         IsRead BIT NOT NULL CONSTRAINT DF_UserNotifications_IsRead DEFAULT 0,
         CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_UserNotifications_CreatedAt DEFAULT SYSUTCDATETIME(),
         ReadAt DATETIME2(0) NULL,
         CONSTRAINT FK_UserNotifications_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id)
       );

       CREATE INDEX IX_UserNotifications_UserId_CreatedAt
       ON dbo.UserNotifications(UserId, CreatedAt DESC);
     END`,
  );
}

async function createUserNotification({ userId, type, title, message, refId }) {
  if (!userId || !type || !title || !message) return;
  await ensureNotificationsTable();
  const pool = await getPool();
  await pool
    .request()
    .input("id", sql.UniqueIdentifier, createGuid())
    .input("userId", sql.UniqueIdentifier, String(userId))
    .input("type", sql.NVarChar(50), String(type))
    .input("title", sql.NVarChar(150), String(title))
    .input("message", sql.NVarChar(500), String(message))
    .input("refId", sql.UniqueIdentifier, refId || null)
    .query(
      `INSERT INTO dbo.UserNotifications(Id, UserId, [Type], Title, [Message], RefId, IsRead)
       VALUES(@id, @userId, @type, @title, @message, @refId, 0)`,
    );
}

function createGuid() {
  if (typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  const bytes = crypto.randomBytes(16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString("hex");
  return `${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}`;
}

function normalizeImageUrls(body) {
  const fromArray = Array.isArray(body.imageUrls) ? body.imageUrls : [];
  const fromSingle = body.imageUrl ? [body.imageUrl] : [];

  const normalized = [...fromArray, ...fromSingle]
    .map((value) => String(value || "").trim())
    .filter((value) => value.length > 0);

  return [...new Set(normalized)];
}

function normalizeSizeStocks(body) {
  const raw = body?.sizeStocks;
  if (!raw || typeof raw !== "object") return {};

  const result = {};
  for (const [sizeRaw, stockRaw] of Object.entries(raw)) {
    const size = String(sizeRaw || "")
      .trim()
      .toUpperCase();
    if (!size) continue;
    const stock = Number(stockRaw || 0);
    result[size] = Number.isFinite(stock) ? Math.max(0, Math.trunc(stock)) : 0;
  }
  return result;
}

function normalizeColorImages(body) {
  const raw = body?.colorImages;
  if (!raw || typeof raw !== "object") return {};

  const result = {};
  for (const [hexRaw, imagesRaw] of Object.entries(raw)) {
    const hex = String(hexRaw || "")
      .trim()
      .toUpperCase();
    if (!hex) continue;
    const normalizedHex = hex.startsWith("#") ? hex : `#${hex}`;
    const images = Array.isArray(imagesRaw) ? imagesRaw : [imagesRaw];
    result[normalizedHex] = [
      ...new Set(
        images
          .map((value) => String(value || "").trim())
          .filter((value) => value.length > 0),
      ),
    ];
  }
  return result;
}

async function ensureProductImagesColorColumn() {
  const pool = await getPool();
  await pool.request().query(
    `IF COL_LENGTH('dbo.ProductImages', 'ColorHex') IS NULL
     BEGIN
       ALTER TABLE dbo.ProductImages
       ADD ColorHex NVARCHAR(10) NULL;
     END`,
  );
}

async function ensureProductOwnerColumn() {
  const pool = await getPool();
  await pool.request().query(
    `IF COL_LENGTH('dbo.Products', 'OwnerId') IS NULL
     BEGIN
       ALTER TABLE dbo.Products
       ADD OwnerId UNIQUEIDENTIFIER NULL;
     END`,
  );
}

async function ensureCategoriesTable() {
  const pool = await getPool();
  await pool.request().query(
    `IF OBJECT_ID('dbo.Categories', 'U') IS NULL
     BEGIN
       CREATE TABLE dbo.Categories (
         Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_Categories PRIMARY KEY,
         Name NVARCHAR(120) NOT NULL,
         [Description] NVARCHAR(500) NULL,
         ImageUrl NVARCHAR(500) NULL,
         IsActive BIT NOT NULL CONSTRAINT DF_Categories_IsActive DEFAULT 1,
         CreatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Categories_CreatedAt DEFAULT SYSUTCDATETIME(),
         UpdatedAt DATETIME2(0) NOT NULL CONSTRAINT DF_Categories_UpdatedAt DEFAULT SYSUTCDATETIME(),
         CONSTRAINT UQ_Categories_Name UNIQUE (Name)
       );
     END`,
  );
}

app.get("/api/health", async (_req, res) => {
  try {
    const pool = await getPool();
    await pool.request().query("SELECT 1 AS ok");
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post("/api/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res
        .status(400)
        .json({ message: "Email and password are required" });
    }

    const pool = await getPool();

    const result = await pool
      .request()
      .input("email", sql.NVarChar(150), email)
      .query(
        `SELECT TOP 1 Id, FullName, Email, Phone, PasswordHash, Role, IsActive
         FROM dbo.Users
         WHERE Email = @email AND IsActive = 1`,
      );

    if (result.recordset.length === 0) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const user = result.recordset[0];
    const passwordMatch = bcrypt.compareSync(password, user.PasswordHash);

    if (!passwordMatch) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const token = issueToken(user);
    const { PasswordHash, ...userWithoutPassword } = user;

    res.json({ token, user: userWithoutPassword });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/auth/register", async (req, res) => {
  try {
    const { fullName, email, phone, password } = req.body;

    if (!fullName || !email || !password) {
      return res
        .status(400)
        .json({ message: "Full name, email and password are required" });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const pool = await getPool();

    const existed = await pool
      .request()
      .input("email", sql.NVarChar(150), normalizedEmail)
      .query(`SELECT TOP 1 Id FROM dbo.Users WHERE Email = @email`);

    if (existed.recordset.length > 0) {
      return res.status(409).json({ message: "Email already exists" });
    }

    const hashedPassword = bcrypt.hashSync(String(password), 10);

    const created = await pool
      .request()
      .input("fullName", sql.NVarChar(120), String(fullName).trim())
      .input("email", sql.NVarChar(150), normalizedEmail)
      .input("phone", sql.NVarChar(20), phone || null)
      .input("password", sql.NVarChar(255), hashedPassword)
      .query(
        `INSERT INTO dbo.Users(FullName, Email, Phone, PasswordHash, Role, IsActive)
         OUTPUT INSERTED.Id, INSERTED.FullName, INSERTED.Email, INSERTED.Phone, INSERTED.Role, INSERTED.IsActive
         VALUES(@fullName, @email, @phone, @password, 'customer', 1)`,
      );

    const user = created.recordset[0];
    const token = issueToken(user);

    res.status(201).json({ token, user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/auth/me", async (req, res) => {
  try {
    const payload = getTokenPayload(req);
    if (!payload?.sub) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input("id", sql.UniqueIdentifier, String(payload.sub))
      .query(
        `SELECT TOP 1 Id, FullName, Email, Phone, Role, IsActive
         FROM dbo.Users
         WHERE Id = @id AND IsActive = 1`,
      );

    if (result.recordset.length === 0) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    res.json(result.recordset[0]);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch("/api/auth/me", async (req, res) => {
  try {
    const payload = getTokenPayload(req);
    if (!payload?.sub) {
      return res.status(401).json({ message: "Unauthorized" });
    }

    const { fullName, email, phone } = req.body;

    // Validate inputs
    if (!fullName && !email && !phone === undefined) {
      return res
        .status(400)
        .json({ message: "At least one field is required to update" });
    }

    const pool = await getPool();
    const userId = String(payload.sub);

    // Check if new email already exists (if email is being changed)
    if (email) {
      const normalizedEmail = String(email).trim().toLowerCase();
      const emailCheck = await pool
        .request()
        .input("email", sql.NVarChar(150), normalizedEmail)
        .input("userId", sql.UniqueIdentifier, userId)
        .query(
          `SELECT TOP 1 Id FROM dbo.Users WHERE Email = @email AND Id != @userId`,
        );

      if (emailCheck.recordset.length > 0) {
        return res.status(409).json({ message: "Email already in use" });
      }
    }

    // Update user profile
    const updateRequest = pool
      .request()
      .input("id", sql.UniqueIdentifier, userId);

    if (fullName !== undefined) {
      updateRequest.input(
        "fullName",
        sql.NVarChar(120),
        String(fullName).trim(),
      );
    }
    if (email !== undefined) {
      updateRequest.input(
        "email",
        sql.NVarChar(150),
        String(email).trim().toLowerCase(),
      );
    }
    if (phone !== undefined) {
      updateRequest.input(
        "phone",
        sql.NVarChar(20),
        phone ? String(phone).trim() : null,
      );
    }

    const setClauses = [];
    if (fullName !== undefined) setClauses.push("FullName = @fullName");
    if (email !== undefined) setClauses.push("Email = @email");
    if (phone !== undefined) setClauses.push("Phone = @phone");
    setClauses.push("UpdatedAt = SYSUTCDATETIME()");

    const updateQuery = `UPDATE dbo.Users
                        SET ${setClauses.join(", ")}
                        WHERE Id = @id
                        
                        SELECT TOP 1 Id, FullName, Email, Phone, Role, IsActive
                        FROM dbo.Users
                        WHERE Id = @id AND IsActive = 1`;

    const result = await updateRequest.query(updateQuery);

    if (result.recordset.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    res.json({
      message: "Profile updated successfully",
      user: result.recordset[0],
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/auth/logout", requireAuth, (_req, res) => {
  try {
    // Logout is primarily handled on the frontend by deleting the token
    // This endpoint just confirms the logout action
    res.json({ message: "Logged out successfully" });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// OTP Email Verification Endpoints
app.post("/api/auth/send-otp", async (req, res) => {
  try {
    const { email } = req.body;

    if (!email) {
      return res.status(400).json({ message: "Email is required" });
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({ message: "Invalid email format" });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const pool = await getPool();

    // Check if user exists
    const userResult = await pool
      .request()
      .input("email", sql.NVarChar(255), normalizedEmail)
      .query("SELECT Id, FullName, Email FROM dbo.Users WHERE Email = @email");

    if (userResult.recordset.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    const user = userResult.recordset[0];

    // Generate 6-digit OTP
    const otpLength = Number(process.env.OTP_LENGTH || 6);
    const otpMin = 10 ** Math.max(otpLength - 1, 0);
    const otpMax = 10 ** otpLength - 1;
    const otp = Math.floor(
      otpMin + Math.random() * (otpMax - otpMin + 1),
    ).toString();
    const otpExpiration = new Date(
      Date.now() + parseInt(process.env.OTP_EXPIRATION_TIME || 300, 10) * 1000,
    );

    // Save OTP to database
    await pool
      .request()
      .input("userId", sql.UniqueIdentifier, user.Id)
      .input("email", sql.NVarChar(255), normalizedEmail)
      .input("otpCode", sql.NVarChar(10), otp)
      .input("expiresAt", sql.DateTime2, otpExpiration)
      .input(
        "maxAttempts",
        sql.Int,
        parseInt(process.env.OTP_MAX_ATTEMPTS || 3, 10),
      ).query(`
        DELETE FROM dbo.UserOTP WHERE UserId = @userId AND GETUTCDATE() < ExpiresAt AND IsExpired = 0;
        INSERT INTO dbo.UserOTP (UserId, Email, OTPCode, Attempts, MaxAttempts, IsVerified, IsExpired, CreatedAt, ExpiresAt)
        VALUES (@userId, @email, @otpCode, 0, @maxAttempts, 0, 0, GETUTCDATE(), @expiresAt)
      `);

    // Send OTP email
    const emailService = new EmailService();
    const emailResult = await emailService.sendOtpEmail(
      normalizedEmail,
      otp,
      user.FullName,
    );

    if (!emailResult.success) {
      return res.status(500).json({ message: "Failed to send OTP email" });
    }

    res.json({
      message: "OTP sent successfully",
      expiresIn: parseInt(process.env.OTP_EXPIRATION_TIME || 300, 10),
    });
  } catch (error) {
    console.error("Send OTP error:", error);
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/auth/verify-otp", async (req, res) => {
  try {
    const { email, otpCode } = req.body;

    if (!email || !otpCode) {
      return res
        .status(400)
        .json({ message: "Email and OTP code are required" });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const normalizedOtpCode = String(otpCode).trim();
    const pool = await getPool();

    // Get user by email
    const userResult = await pool
      .request()
      .input("email", sql.NVarChar(255), normalizedEmail)
      .query("SELECT Id, FullName, Email FROM dbo.Users WHERE Email = @email");

    if (userResult.recordset.length === 0) {
      return res.status(404).json({ message: "User not found" });
    }

    const user = userResult.recordset[0];

    // Get OTP record
    const otpResult = await pool
      .request()
      .input("userId", sql.UniqueIdentifier, user.Id)
      .input("email", sql.NVarChar(255), normalizedEmail).query(`
        SELECT Id, OTPCode, Attempts, MaxAttempts, IsExpired, ExpiresAt, IsVerified
        FROM dbo.UserOTP 
        WHERE UserId = @userId AND Email = @email AND IsVerified = 0 AND IsExpired = 0
        ORDER BY CreatedAt DESC
      `);

    if (otpResult.recordset.length === 0) {
      return res
        .status(404)
        .json({ message: "OTP not found or already expired" });
    }

    const otpRecord = otpResult.recordset[0];

    // Check if OTP is expired
    if (new Date() > new Date(otpRecord.ExpiresAt)) {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, otpRecord.Id)
        .query("UPDATE dbo.UserOTP SET IsExpired = 1 WHERE Id = @id");
      return res.status(400).json({ message: "OTP has expired" });
    }

    // Check max attempts
    if (otpRecord.Attempts >= otpRecord.MaxAttempts) {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, otpRecord.Id)
        .query("UPDATE dbo.UserOTP SET IsExpired = 1 WHERE Id = @id");
      return res.status(400).json({
        message: "Maximum OTP attempts exceeded. Please request a new OTP.",
      });
    }

    // Verify OTP code
    if (otpRecord.OTPCode !== normalizedOtpCode) {
      // Increment attempts
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, otpRecord.Id)
        .input("newAttempts", sql.Int, otpRecord.Attempts + 1)
        .query("UPDATE dbo.UserOTP SET Attempts = @newAttempts WHERE Id = @id");

      const remainingAttempts = otpRecord.MaxAttempts - otpRecord.Attempts - 1;
      return res.status(400).json({
        message: "Invalid OTP code",
        remainingAttempts,
      });
    }

    // OTP is valid, mark as verified
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, otpRecord.Id)
      .query(
        "UPDATE dbo.UserOTP SET IsVerified = 1, VerifiedAt = GETUTCDATE() WHERE Id = @id",
      );

    // Generate JWT token for verified identity
    const token = jwt.sign(
      { sub: user.Id, email: user.Email, type: "otp-verified" },
      process.env.JWT_SECRET,
      { expiresIn: "1h" },
    );

    res.json({
      message: "OTP verified successfully",
      token,
      user: {
        id: user.Id,
        email: user.Email,
        fullName: user.FullName,
      },
    });
  } catch (error) {
    console.error("Verify OTP error:", error);
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/products", async (req, res) => {
  try {
    await ensureProductImagesColorColumn();
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === "owner";
    const ownerId = isOwner ? String(payload.sub || "") : null;
    const pool = await getPool();
    const productsRequest = pool.request();
    if (isOwner) {
      productsRequest.input("ownerId", sql.UniqueIdentifier, ownerId);
    }
    const productsResult = await productsRequest.query(
      `SELECT p.Id, p.OwnerId, p.Name, p.Category, p.[Description], p.Price, p.DiscountPercent, p.Stock,
              COALESCE(s.SoldCount, 0) AS SoldCount
       FROM dbo.Products p
       LEFT JOIN (
         SELECT oi.ProductId, SUM(oi.Quantity) AS SoldCount
         FROM dbo.OrderItems oi
         INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
         WHERE LOWER(o.[Status]) <> 'cancelled'
         GROUP BY oi.ProductId
       ) s ON s.ProductId = p.Id
       WHERE p.IsActive = 1
         ${isOwner ? "AND p.OwnerId = @ownerId" : ""}
       ORDER BY CreatedAt DESC`,
    );

    const imagesResult = await pool.request().query(
      `SELECT pi.ProductId, pi.ImageUrl, pi.ColorHex, pi.SortOrder, pi.Id
       FROM dbo.ProductImages pi
       INNER JOIN dbo.Products p ON p.Id = pi.ProductId
       WHERE p.IsActive = 1
       ORDER BY pi.ProductId ASC, pi.SortOrder ASC, pi.Id ASC`,
    );

    const variantsResult = await pool.request().query(
      `SELECT pv.ProductId, pv.SizeLabel, pv.Stock, pv.ColorHex
       FROM dbo.ProductVariants pv
       INNER JOIN dbo.Products p ON p.Id = pv.ProductId
       WHERE p.IsActive = 1
       ORDER BY pv.ProductId ASC, pv.SizeLabel ASC`,
    );

    const imagesByProduct = new Map();
    const colorImagesByProduct = new Map();
    for (const row of imagesResult.recordset) {
      const key = String(row.ProductId).toLowerCase();
      if (!imagesByProduct.has(key)) {
        imagesByProduct.set(key, []);
      }
      imagesByProduct.get(key).push(row.ImageUrl);

      const colorHex = String(row.ColorHex || "")
        .trim()
        .toUpperCase();
      if (colorHex) {
        if (!colorImagesByProduct.has(key)) {
          colorImagesByProduct.set(key, {});
        }
        const group = colorImagesByProduct.get(key);
        if (!group[colorHex]) group[colorHex] = [];
        group[colorHex].push(row.ImageUrl);
      }
    }

    const sizeStocksByProduct = new Map();
    for (const row of variantsResult.recordset) {
      const key = String(row.ProductId).toLowerCase();
      if (!sizeStocksByProduct.has(key)) {
        sizeStocksByProduct.set(key, {});
      }
      const size = String(row.SizeLabel || "")
        .trim()
        .toUpperCase();
      const stock = Number(row.Stock || 0);
      if (size) {
        sizeStocksByProduct.get(key)[size] =
          (sizeStocksByProduct.get(key)[size] || 0) + stock;
      }
    }

    const mapped = productsResult.recordset.map((product) => {
      const productKey = String(product.Id).toLowerCase();
      const imageUrls = imagesByProduct.get(productKey) || [];
      return {
        ...product,
        ImageUrls: imageUrls,
        ImageUrl: imageUrls[0] || null,
        SizeStocks: sizeStocksByProduct.get(productKey) || {},
        ColorImages: colorImagesByProduct.get(productKey) || {},
      };
    });

    res.json(mapped);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/products", async (req, res) => {
  try {
    await ensureProductImagesColorColumn();
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const {
      id,
      ownerId,
      name,
      category,
      description,
      price,
      discountPercent = 0,
      stock = 0,
    } = req.body;
    const imageUrls = normalizeImageUrls(req.body);
    let sizeStocks = normalizeSizeStocks(req.body);
    let colorImages = normalizeColorImages(req.body);

    if (Object.keys(sizeStocks).length === 0 && Array.isArray(req.body.sizes)) {
      const sizes = req.body.sizes
        .map((value) =>
          String(value || "")
            .trim()
            .toUpperCase(),
        )
        .filter((value) => value.length > 0);
      if (sizes.length > 0) {
        const base = Math.floor(Number(stock || 0) / sizes.length);
        let remainder = Number(stock || 0) - base * sizes.length;
        for (const size of sizes) {
          sizeStocks[size] = base + (remainder > 0 ? 1 : 0);
          if (remainder > 0) remainder -= 1;
        }
      }
    }

    if (Object.keys(colorImages).length === 0 && imageUrls.length > 0) {
      colorImages = { "#000000": imageUrls };
    }

    const stockFromSizes = Object.values(sizeStocks).reduce(
      (sum, value) => sum + Number(value || 0),
      0,
    );
    const finalStock =
      Object.keys(sizeStocks).length > 0 ? stockFromSizes : Number(stock || 0);
    const finalOwnerId =
      payload?.role === "owner" ? String(payload.sub || "") : ownerId || null;

    const pool = await getPool();

    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .input("ownerId", sql.UniqueIdentifier, finalOwnerId || null)
      .input("name", sql.NVarChar(200), name)
      .input("category", sql.NVarChar(80), category)
      .input("description", sql.NVarChar(sql.MAX), description || "")
      .input("price", sql.Decimal(18, 2), Number(price || 0))
      .input("discountPercent", sql.Decimal(5, 2), Number(discountPercent || 0))
      .input("stock", sql.Int, finalStock)
      .query(
        `INSERT INTO dbo.Products(Id, OwnerId, Name, Category, [Description], Price, DiscountPercent, Stock, IsActive)
        VALUES(@id, @ownerId, @name, @category, @description, @price, @discountPercent, @stock, 1)`,
      );

    const insertedImages = new Set();
    let sortOrder = 1;
    for (const [colorHex, urls] of Object.entries(colorImages)) {
      for (const imageUrl of urls) {
        const key = `${colorHex}|${imageUrl}`;
        if (insertedImages.has(key)) continue;
        insertedImages.add(key);
        await pool
          .request()
          .input("productId", sql.UniqueIdentifier, id)
          .input("imageUrl", sql.NVarChar(500), imageUrl)
          .input("colorHex", sql.NVarChar(10), colorHex)
          .input("sortOrder", sql.Int, sortOrder)
          .query(
            `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
             VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`,
          );
        sortOrder += 1;
      }
    }

    for (const imageUrl of imageUrls) {
      const key = `|${imageUrl}`;
      if (insertedImages.has(key)) continue;
      insertedImages.add(key);
      await pool
        .request()
        .input("productId", sql.UniqueIdentifier, id)
        .input("imageUrl", sql.NVarChar(500), imageUrl)
        .input("colorHex", sql.NVarChar(10), null)
        .input("sortOrder", sql.Int, sortOrder)
        .query(
          `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
           VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`,
        );
      sortOrder += 1;
    }

    const variantColor = Object.keys(colorImages)[0] || "#000000";
    for (const [size, stockValue] of Object.entries(sizeStocks)) {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, createGuid())
        .input("productId", sql.UniqueIdentifier, id)
        .input("sizeLabel", sql.NVarChar(10), size)
        .input("colorHex", sql.NVarChar(10), variantColor)
        .input("stock", sql.Int, Number(stockValue || 0))
        .query(
          `INSERT INTO dbo.ProductVariants(Id, ProductId, SizeLabel, ColorHex, Stock)
           VALUES(@id, @productId, @sizeLabel, @colorHex, @stock)`,
        );
    }

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/products/:id", async (req, res) => {
  try {
    const { id } = req.params;
    await ensureProductImagesColorColumn();
    await ensureProductOwnerColumn();
    const pool = await getPool();

    const productResult = await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .query(
        `SELECT p.Id, p.OwnerId, p.Name, p.Category, p.[Description], p.Price, p.DiscountPercent, p.Stock,
                COALESCE(s.SoldCount, 0) AS SoldCount
         FROM dbo.Products p
         LEFT JOIN (
           SELECT oi.ProductId, SUM(oi.Quantity) AS SoldCount
           FROM dbo.OrderItems oi
           INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
           WHERE LOWER(o.[Status]) <> 'cancelled'
           GROUP BY oi.ProductId
         ) s ON s.ProductId = p.Id
         WHERE p.Id = @id AND p.IsActive = 1`,
      );

    if (productResult.recordset.length === 0) {
      return res.status(404).json({ message: "Product not found" });
    }

    const product = productResult.recordset[0];
    const productKey = String(product.Id).toLowerCase();

    const imagesResult = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .query(
        `SELECT pi.ProductId, pi.ImageUrl, pi.ColorHex, pi.SortOrder, pi.Id
         FROM dbo.ProductImages pi
         WHERE pi.ProductId = @productId
         ORDER BY pi.SortOrder ASC, pi.Id ASC`,
      );

    const variantsResult = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .query(
        `SELECT pv.ProductId, pv.SizeLabel, pv.Stock, pv.ColorHex
         FROM dbo.ProductVariants pv
         WHERE pv.ProductId = @productId
         ORDER BY pv.SizeLabel ASC`,
      );

    const imageUrls = imagesResult.recordset.map((row) => row.ImageUrl);
    const colorImagesByProduct = {};
    for (const row of imagesResult.recordset) {
      const colorHex = String(row.ColorHex || "")
        .trim()
        .toUpperCase();
      if (colorHex) {
        if (!colorImagesByProduct[colorHex])
          colorImagesByProduct[colorHex] = [];
        colorImagesByProduct[colorHex].push(row.ImageUrl);
      }
    }

    const sizeStocksByProduct = {};
    for (const row of variantsResult.recordset) {
      const size = String(row.SizeLabel || "")
        .trim()
        .toUpperCase();
      const stock = Number(row.Stock || 0);
      if (size) {
        sizeStocksByProduct[size] = (sizeStocksByProduct[size] || 0) + stock;
      }
    }

    const response = {
      ...product,
      ImageUrls: imageUrls,
      ImageUrl: imageUrls[0] || null,
      SizeStocks: sizeStocksByProduct,
      ColorImages: colorImagesByProduct,
    };

    res.json(response);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Advanced Product Search with Filters
app.get("/api/products/search/advanced", async (req, res) => {
  try {
    const {
      q = "",
      minPrice = 0,
      maxPrice = 999999999,
      categoryId = null,
      inStockOnly = false,
      sortBy = "newest", // newest, price-asc, price-desc, rating
      page = 1,
      limit = 50,
    } = req.query;

    const pageNum = Math.max(1, parseInt(page, 10) || 1);
    const limitNum = Math.max(1, Math.min(100, parseInt(limit, 10) || 50));
    const offset = (pageNum - 1) * limitNum;
    const minPriceNum = Math.max(0, parseFloat(minPrice) || 0);
    const maxPriceNum = Math.max(
      minPriceNum,
      parseFloat(maxPrice) || 999999999,
    );
    const searchQuery = String(q || "").trim();
    const inStock = String(inStockOnly).toLowerCase() === "true";

    const pool = await getPool();

    // Build WHERE clauses dynamically
    const whereClauses = ["p.IsActive = 1"];

    // Search by name or description
    if (searchQuery) {
      whereClauses.push(
        `(LOWER(p.Name) LIKE @searchQuery OR LOWER(p.[Description]) LIKE @searchQuery)`,
      );
    }

    // Price range filter
    whereClauses.push("p.Price BETWEEN @minPrice AND @maxPrice");

    // Category filter
    if (categoryId) {
      whereClauses.push("p.Category = @categoryId");
    }

    // In stock filter
    if (inStock) {
      whereClauses.push("p.Stock > 0");
    }

    // Determine sort order
    let orderByClause = "p.CreatedAt DESC"; // default newest
    if (sortBy === "price-asc") {
      orderByClause = "p.Price ASC";
    } else if (sortBy === "price-desc") {
      orderByClause = "p.Price DESC";
    } else if (sortBy === "rating") {
      orderByClause = "COALESCE(r.AvgRating, 0) DESC, SoldCount DESC";
    }

    const whereSQL = whereClauses.join(" AND ");

    // Get total count
    const countRequest = pool.request();
    countRequest.input("minPrice", sql.Decimal(18, 2), minPriceNum);
    countRequest.input("maxPrice", sql.Decimal(18, 2), maxPriceNum);
    if (searchQuery) {
      countRequest.input("searchQuery", sql.NVarChar(255), `%${searchQuery}%`);
    }
    if (categoryId) {
      countRequest.input("categoryId", sql.NVarChar(150), categoryId);
    }

    const countResult = await countRequest.query(
      `SELECT COUNT(*) AS total FROM dbo.Products p WHERE ${whereSQL}`,
    );
    const total = countResult.recordset[0]?.total || 0;

    // Get paginated results
    const queryRequest = pool.request();
    queryRequest.input("minPrice", sql.Decimal(18, 2), minPriceNum);
    queryRequest.input("maxPrice", sql.Decimal(18, 2), maxPriceNum);
    queryRequest.input("offset", sql.Int, offset);
    queryRequest.input("limit", sql.Int, limitNum);
    if (searchQuery) {
      queryRequest.input("searchQuery", sql.NVarChar(255), `%${searchQuery}%`);
    }
    if (categoryId) {
      queryRequest.input("categoryId", sql.NVarChar(150), categoryId);
    }

    const productsResult = await queryRequest.query(
      `SELECT p.Id, p.OwnerId, p.Name, p.Category, p.[Description], p.Price, p.DiscountPercent, p.Stock,
              COALESCE(s.SoldCount, 0) AS SoldCount,
              COALESCE(r.AvgRating, 0) AS AvgRating,
              COALESCE(r.ReviewCount, 0) AS ReviewCount
       FROM dbo.Products p
       LEFT JOIN (
         SELECT oi.ProductId, SUM(oi.Quantity) AS SoldCount
         FROM dbo.OrderItems oi
         INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
         WHERE LOWER(o.[Status]) <> 'cancelled'
         GROUP BY oi.ProductId
       ) s ON s.ProductId = p.Id
       LEFT JOIN (
         SELECT ProductId, AVG(CAST(Rating AS FLOAT)) AS AvgRating, COUNT(*) AS ReviewCount
         FROM dbo.ProductReviews
         WHERE Rating > 0
         GROUP BY ProductId
       ) r ON r.ProductId = p.Id
       WHERE ${whereSQL}
       ORDER BY ${orderByClause}
       OFFSET @offset ROWS
       FETCH NEXT @limit ROWS ONLY`,
    );

    const imagesByProductId = new Map();
    if (productsResult.recordset.length > 0) {
      const productIds = productsResult.recordset
        .map((p) => p.Id)
        .filter(Boolean);

      if (productIds.length > 0) {
        const imagesRequest = pool.request();
        const placeholders = productIds.map((_, idx) => `@id${idx}`).join(",");
        productIds.forEach((id, idx) => {
          imagesRequest.input(`id${idx}`, sql.UniqueIdentifier, id);
        });

        const imagesResult = await imagesRequest.query(
          `SELECT ProductId, ImageUrl, SortOrder
           FROM dbo.ProductImages
           WHERE ProductId IN (${placeholders})
           ORDER BY ProductId, SortOrder ASC, Id ASC`,
        );

        for (const image of imagesResult.recordset) {
          const key = String(image.ProductId).toLowerCase();
          if (!imagesByProductId.has(key)) {
            imagesByProductId.set(key, []);
          }
          imagesByProductId.get(key).push(image.ImageUrl);
        }
      }
    }

    const products = productsResult.recordset.map((product) => {
      const key = String(product.Id).toLowerCase();
      const imageUrls = imagesByProductId.get(key) || [];
      return {
        ...product,
        ImageUrl: imageUrls[0] || null,
        ImageUrls: imageUrls,
      };
    });

    res.json({
      success: true,
      data: products,
      pagination: {
        total,
        page: pageNum,
        limit: limitNum,
        totalPages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error("Search error:", error);
    res.status(500).json({ message: error.message });
  }
});

app.put("/api/products/:id", async (req, res) => {
  try {
    const { id } = req.params;
    await ensureProductImagesColorColumn();
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === "owner";
    const {
      ownerId,
      name,
      category,
      description,
      price,
      discountPercent = 0,
      stock = 0,
    } = req.body;
    const imageUrls = normalizeImageUrls(req.body);
    let sizeStocks = normalizeSizeStocks(req.body);
    let colorImages = normalizeColorImages(req.body);

    if (Object.keys(sizeStocks).length === 0 && Array.isArray(req.body.sizes)) {
      const sizes = req.body.sizes
        .map((value) =>
          String(value || "")
            .trim()
            .toUpperCase(),
        )
        .filter((value) => value.length > 0);
      if (sizes.length > 0) {
        const base = Math.floor(Number(stock || 0) / sizes.length);
        let remainder = Number(stock || 0) - base * sizes.length;
        for (const size of sizes) {
          sizeStocks[size] = base + (remainder > 0 ? 1 : 0);
          if (remainder > 0) remainder -= 1;
        }
      }
    }

    if (Object.keys(colorImages).length === 0 && imageUrls.length > 0) {
      colorImages = { "#000000": imageUrls };
    }

    const stockFromSizes = Object.values(sizeStocks).reduce(
      (sum, value) => sum + Number(value || 0),
      0,
    );
    const finalStock =
      Object.keys(sizeStocks).length > 0 ? stockFromSizes : Number(stock || 0);

    const pool = await getPool();

    if (isOwner) {
      const owned = await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .input("ownerId", sql.UniqueIdentifier, String(payload.sub || ""))
        .query(
          `SELECT TOP 1 Id
           FROM dbo.Products
           WHERE Id = @id AND OwnerId = @ownerId AND IsActive = 1`,
        );

      if (owned.recordset.length === 0) {
        return res.status(403).json({ message: "Forbidden" });
      }
    }

    const finalOwnerId = isOwner ? String(payload.sub || "") : ownerId || null;

    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .input("ownerId", sql.UniqueIdentifier, finalOwnerId)
      .input("name", sql.NVarChar(200), name)
      .input("category", sql.NVarChar(80), category)
      .input("description", sql.NVarChar(sql.MAX), description || "")
      .input("price", sql.Decimal(18, 2), Number(price || 0))
      .input("discountPercent", sql.Decimal(5, 2), Number(discountPercent || 0))
      .input("stock", sql.Int, finalStock)
      .query(
        `UPDATE dbo.Products
         SET OwnerId=COALESCE(@ownerId, OwnerId),
           Name=@name, Category=@category, [Description]=@description,
             Price=@price, DiscountPercent=@discountPercent, Stock=@stock,
             UpdatedAt=SYSUTCDATETIME()
         WHERE Id=@id`,
      );

    await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .query(`DELETE FROM dbo.ProductImages WHERE ProductId=@productId`);

    await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .query(`DELETE FROM dbo.ProductVariants WHERE ProductId=@productId`);

    const insertedImages = new Set();
    let sortOrder = 1;
    for (const [colorHex, urls] of Object.entries(colorImages)) {
      for (const imageUrl of urls) {
        const key = `${colorHex}|${imageUrl}`;
        if (insertedImages.has(key)) continue;
        insertedImages.add(key);
        await pool
          .request()
          .input("productId", sql.UniqueIdentifier, id)
          .input("imageUrl", sql.NVarChar(500), imageUrl)
          .input("colorHex", sql.NVarChar(10), colorHex)
          .input("sortOrder", sql.Int, sortOrder)
          .query(
            `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
             VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`,
          );
        sortOrder += 1;
      }
    }

    for (const imageUrl of imageUrls) {
      const key = `|${imageUrl}`;
      if (insertedImages.has(key)) continue;
      insertedImages.add(key);
      await pool
        .request()
        .input("productId", sql.UniqueIdentifier, id)
        .input("imageUrl", sql.NVarChar(500), imageUrl)
        .input("colorHex", sql.NVarChar(10), null)
        .input("sortOrder", sql.Int, sortOrder)
        .query(
          `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
           VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`,
        );
      sortOrder += 1;
    }

    const variantColor = Object.keys(colorImages)[0] || "#000000";
    for (const [size, stockValue] of Object.entries(sizeStocks)) {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, createGuid())
        .input("productId", sql.UniqueIdentifier, id)
        .input("sizeLabel", sql.NVarChar(10), size)
        .input("colorHex", sql.NVarChar(10), variantColor)
        .input("stock", sql.Int, Number(stockValue || 0))
        .query(
          `INSERT INTO dbo.ProductVariants(Id, ProductId, SizeLabel, ColorHex, Stock)
           VALUES(@id, @productId, @sizeLabel, @colorHex, @stock)`,
        );
    }

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.delete("/api/products/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === "owner";
    const pool = await getPool();

    if (isOwner) {
      const owned = await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .input("ownerId", sql.UniqueIdentifier, String(payload.sub || ""))
        .query(
          `SELECT TOP 1 Id
           FROM dbo.Products
           WHERE Id = @id AND OwnerId = @ownerId AND IsActive = 1`,
        );

      if (owned.recordset.length === 0) {
        return res.status(403).json({ message: "Forbidden" });
      }
    }

    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .query(
        `UPDATE dbo.Products SET IsActive = 0, UpdatedAt=SYSUTCDATETIME() WHERE Id=@id`,
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/categories", async (_req, res) => {
  try {
    await ensureCategoriesTable();
    const pool = await getPool();
    const result = await pool.request().query(
      `SELECT Id, Name, [Description], ImageUrl, IsActive, CreatedAt, UpdatedAt
       FROM dbo.Categories
       WHERE IsActive = 1
       ORDER BY Name ASC`,
    );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/categories", requireAuth, requireAdmin, async (req, res) => {
  try {
    await ensureCategoriesTable();
    const { name, description, imageUrl } = req.body;
    const normalizedName = String(name || "").trim();

    if (!normalizedName) {
      return res.status(400).json({ message: "Category name is required" });
    }

    const pool = await getPool();
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, createGuid())
      .input("name", sql.NVarChar(120), normalizedName)
      .input(
        "description",
        sql.NVarChar(500),
        description ? String(description).trim() : null,
      )
      .input(
        "imageUrl",
        sql.NVarChar(500),
        imageUrl ? String(imageUrl).trim() : null,
      )
      .query(
        `INSERT INTO dbo.Categories(Id, Name, [Description], ImageUrl, IsActive)
         VALUES(@id, @name, @description, @imageUrl, 1)`,
      );

    res.status(201).json({ ok: true });
  } catch (error) {
    if (String(error.message || "").includes("UQ_Categories_Name")) {
      return res.status(409).json({ message: "Category name already exists" });
    }
    res.status(500).json({ message: error.message });
  }
});

app.put("/api/categories/:id", requireAuth, requireAdmin, async (req, res) => {
  try {
    await ensureCategoriesTable();
    const { id } = req.params;
    const { name, description, imageUrl, isActive } = req.body;
    const normalizedName = String(name || "").trim();

    if (!normalizedName) {
      return res.status(400).json({ message: "Category name is required" });
    }

    const pool = await getPool();
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .input("name", sql.NVarChar(120), normalizedName)
      .input(
        "description",
        sql.NVarChar(500),
        description ? String(description).trim() : null,
      )
      .input(
        "imageUrl",
        sql.NVarChar(500),
        imageUrl ? String(imageUrl).trim() : null,
      )
      .input("isActive", sql.Bit, isActive === false ? 0 : 1)
      .query(
        `UPDATE dbo.Categories
         SET Name = @name,
             [Description] = @description,
             ImageUrl = @imageUrl,
             IsActive = @isActive,
             UpdatedAt = SYSUTCDATETIME()
         WHERE Id = @id`,
      );

    res.json({ ok: true });
  } catch (error) {
    if (String(error.message || "").includes("UQ_Categories_Name")) {
      return res.status(409).json({ message: "Category name already exists" });
    }
    res.status(500).json({ message: error.message });
  }
});

app.delete(
  "/api/categories/:id",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      await ensureCategoriesTable();
      const { id } = req.params;
      const pool = await getPool();
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .query(
          `UPDATE dbo.Categories
         SET IsActive = 0,
             UpdatedAt = SYSUTCDATETIME()
         WHERE Id = @id`,
        );

      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  },
);

app.get("/api/products/:id/reviews", async (req, res) => {
  try {
    const { id } = req.params;
    const viewerUserId = String(req.query.userId || "").trim();
    const sortBy = String(req.query.sortBy || "newest")
      .trim()
      .toLowerCase();
    let orderByClause = "pr.CreatedAt DESC";
    if (sortBy === "rating") {
      orderByClause = "pr.Rating DESC, pr.CreatedAt DESC";
    } else if (sortBy === "helpful") {
      orderByClause = "COALESCE(hv.HelpfulCount, 0) DESC, pr.CreatedAt DESC";
    }

    await ensureProductReviewsTable();
    await ensureReviewHelpfulVotesTable();

    const pool = await getPool();
    const result = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .input("viewerUserId", sql.UniqueIdentifier, viewerUserId || null)
      .query(
        `SELECT pr.Id, pr.ProductId, pr.UserId, pr.Rating, pr.Comment, pr.CreatedAt, pr.UpdatedAt,
                u.FullName AS UserName,
                COALESCE(hv.HelpfulCount, 0) AS HelpfulCount,
                CASE WHEN uv.Id IS NULL THEN CAST(0 AS BIT) ELSE CAST(1 AS BIT) END AS IsHelpfulByMe
         FROM dbo.ProductReviews pr
         INNER JOIN dbo.Users u ON u.Id = pr.UserId
         LEFT JOIN (
           SELECT ReviewId, COUNT(*) AS HelpfulCount
           FROM dbo.ReviewHelpfulVotes
           GROUP BY ReviewId
         ) hv ON hv.ReviewId = pr.Id
         LEFT JOIN dbo.ReviewHelpfulVotes uv
           ON uv.ReviewId = pr.Id AND uv.UserId = @viewerUserId
         WHERE pr.ProductId = @productId
         ORDER BY ${orderByClause}`,
      );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/products/:id/can-review", async (req, res) => {
  try {
    const { id } = req.params;
    const userId = String(req.query.userId || "").trim();
    if (!userId) {
      return res.status(400).json({ message: "userId is required" });
    }

    await ensureProductReviewsTable();

    const pool = await getPool();
    const purchasedResult = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .input("userId", sql.UniqueIdentifier, userId)
      .query(
        `SELECT TOP 1 1 AS Purchased
         FROM dbo.OrderItems oi
         INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
         WHERE oi.ProductId = @productId
           AND o.UserId = @userId
           AND LOWER(o.[Status]) <> 'cancelled'`,
      );

    const reviewedResult = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .input("userId", sql.UniqueIdentifier, userId)
      .query(
        `SELECT TOP 1 1 AS Reviewed
         FROM dbo.ProductReviews
         WHERE ProductId = @productId
           AND UserId = @userId`,
      );

    res.json({
      canReview: purchasedResult.recordset.length > 0,
      hasReviewed: reviewedResult.recordset.length > 0,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/products/:id/reviews", async (req, res) => {
  try {
    const { id } = req.params;
    const { userId, rating, comment } = req.body;

    const normalizedUserId = String(userId || "").trim();
    const normalizedComment = String(comment || "").trim();
    const numericRating = Number(rating || 0);

    if (!normalizedUserId) {
      return res.status(400).json({ message: "userId is required" });
    }
    if (
      !Number.isInteger(numericRating) ||
      numericRating < 1 ||
      numericRating > 5
    ) {
      return res
        .status(400)
        .json({ message: "rating must be an integer from 1 to 5" });
    }

    await ensureProductReviewsTable();

    const pool = await getPool();
    const purchasedResult = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .input("userId", sql.UniqueIdentifier, normalizedUserId)
      .query(
        `SELECT TOP 1 1 AS Purchased
         FROM dbo.OrderItems oi
         INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
         WHERE oi.ProductId = @productId
           AND o.UserId = @userId
           AND LOWER(o.[Status]) <> 'cancelled'`,
      );

    if (purchasedResult.recordset.length === 0) {
      return res.status(403).json({
        message: "Only customers who purchased can review this product",
      });
    }

    const existed = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .input("userId", sql.UniqueIdentifier, normalizedUserId)
      .query(
        `SELECT TOP 1 Id
         FROM dbo.ProductReviews
         WHERE ProductId = @productId
           AND UserId = @userId`,
      );

    if (existed.recordset.length > 0) {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, existed.recordset[0].Id)
        .input("rating", sql.Int, numericRating)
        .input("comment", sql.NVarChar(1000), normalizedComment)
        .query(
          `UPDATE dbo.ProductReviews
           SET Rating = @rating,
               Comment = @comment,
               UpdatedAt = SYSUTCDATETIME()
           WHERE Id = @id`,
        );

      const productOwnerResult = await pool
        .request()
        .input("productId", sql.UniqueIdentifier, id)
        .query(`SELECT TOP 1 OwnerId, Name FROM dbo.Products WHERE Id = @productId`);

      const ownerId = String(productOwnerResult.recordset[0]?.OwnerId || "").trim();
      const productName = String(productOwnerResult.recordset[0]?.Name || "Sản phẩm").trim();
      if (ownerId && ownerId !== normalizedUserId) {
        await createUserNotification({
          userId: ownerId,
          type: "review_updated",
          title: "Đánh giá đã được cập nhật",
          message: `Một khách hàng vừa cập nhật đánh giá cho ${productName}.`,
          refId: id,
        });
      }
    } else {
      const reviewId = createGuid();
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, reviewId)
        .input("productId", sql.UniqueIdentifier, id)
        .input("userId", sql.UniqueIdentifier, normalizedUserId)
        .input("rating", sql.Int, numericRating)
        .input("comment", sql.NVarChar(1000), normalizedComment)
        .query(
          `INSERT INTO dbo.ProductReviews(Id, ProductId, UserId, Rating, Comment)
           VALUES(@id, @productId, @userId, @rating, @comment)`,
        );

      const productOwnerResult = await pool
        .request()
        .input("productId", sql.UniqueIdentifier, id)
        .query(`SELECT TOP 1 OwnerId, Name FROM dbo.Products WHERE Id = @productId`);

      const ownerId = String(productOwnerResult.recordset[0]?.OwnerId || "").trim();
      const productName = String(productOwnerResult.recordset[0]?.Name || "Sản phẩm").trim();
      if (ownerId && ownerId !== normalizedUserId) {
        await createUserNotification({
          userId: ownerId,
          type: "review_created",
          title: "Đánh giá mới",
          message: `Một khách hàng vừa để lại đánh giá mới cho ${productName}.`,
          refId: reviewId,
        });
      }
    }

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch("/api/reviews/:reviewId", async (req, res) => {
  try {
    const { reviewId } = req.params;
    const { userId, rating, comment } = req.body;
    const normalizedUserId = String(userId || "").trim();
    const numericRating = Number(rating || 0);
    const normalizedComment = String(comment || "").trim();
    const tokenPayload = getTokenPayload(req);
    const isAdmin =
      String(tokenPayload?.role || "")
        .trim()
        .toLowerCase() === "admin";

    if (
      !Number.isInteger(numericRating) ||
      numericRating < 1 ||
      numericRating > 5
    ) {
      return res
        .status(400)
        .json({ message: "rating must be an integer from 1 to 5" });
    }

    await ensureProductReviewsTable();

    const pool = await getPool();
    const currentReviewResult = await pool
      .request()
      .input("reviewId", sql.UniqueIdentifier, reviewId)
      .query(
        `SELECT TOP 1 Id, UserId
         FROM dbo.ProductReviews
         WHERE Id = @reviewId`,
      );

    if (currentReviewResult.recordset.length === 0) {
      return res.status(404).json({ message: "Review not found" });
    }

    const reviewOwnerId = String(currentReviewResult.recordset[0].UserId || "");
    if (!isAdmin && (!normalizedUserId || normalizedUserId !== reviewOwnerId)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    await pool
      .request()
      .input("reviewId", sql.UniqueIdentifier, reviewId)
      .input("rating", sql.Int, numericRating)
      .input("comment", sql.NVarChar(1000), normalizedComment)
      .query(
        `UPDATE dbo.ProductReviews
         SET Rating = @rating,
             Comment = @comment,
             UpdatedAt = SYSUTCDATETIME()
         WHERE Id = @reviewId`,
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.delete("/api/reviews/:reviewId", async (req, res) => {
  try {
    const { reviewId } = req.params;
    const userIdFromQuery = String(req.query.userId || "").trim();
    const userIdFromBody = String(req.body?.userId || "").trim();
    const normalizedUserId = userIdFromBody || userIdFromQuery;
    const tokenPayload = getTokenPayload(req);
    const isAdmin =
      String(tokenPayload?.role || "")
        .trim()
        .toLowerCase() === "admin";

    await ensureProductReviewsTable();
    await ensureReviewHelpfulVotesTable();

    const pool = await getPool();
    const currentReviewResult = await pool
      .request()
      .input("reviewId", sql.UniqueIdentifier, reviewId)
      .query(
        `SELECT TOP 1 Id, UserId
         FROM dbo.ProductReviews
         WHERE Id = @reviewId`,
      );

    if (currentReviewResult.recordset.length === 0) {
      return res.status(404).json({ message: "Review not found" });
    }

    const reviewOwnerId = String(currentReviewResult.recordset[0].UserId || "");
    if (!isAdmin && (!normalizedUserId || normalizedUserId !== reviewOwnerId)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    await pool
      .request()
      .input("reviewId", sql.UniqueIdentifier, reviewId)
      .query(`DELETE FROM dbo.ReviewHelpfulVotes WHERE ReviewId = @reviewId`);

    await pool
      .request()
      .input("reviewId", sql.UniqueIdentifier, reviewId)
      .query(`DELETE FROM dbo.ProductReviews WHERE Id = @reviewId`);

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/reviews/:reviewId/helpful", async (req, res) => {
  try {
    const { reviewId } = req.params;
    const userId = String(req.body?.userId || "").trim();
    if (!userId) {
      return res.status(400).json({ message: "userId is required" });
    }

    await ensureProductReviewsTable();
    await ensureReviewHelpfulVotesTable();

    const pool = await getPool();
    const exists = await pool
      .request()
      .input("reviewId", sql.UniqueIdentifier, reviewId)
      .input("userId", sql.UniqueIdentifier, userId)
      .query(
        `SELECT TOP 1 Id
         FROM dbo.ReviewHelpfulVotes
         WHERE ReviewId = @reviewId
           AND UserId = @userId`,
      );

    if (exists.recordset.length > 0) {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, exists.recordset[0].Id)
        .query(`DELETE FROM dbo.ReviewHelpfulVotes WHERE Id = @id`);
    } else {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, createGuid())
        .input("reviewId", sql.UniqueIdentifier, reviewId)
        .input("userId", sql.UniqueIdentifier, userId)
        .query(
          `INSERT INTO dbo.ReviewHelpfulVotes(Id, ReviewId, UserId)
           VALUES(@id, @reviewId, @userId)`,
        );
    }

    const countResult = await pool
      .request()
      .input("reviewId", sql.UniqueIdentifier, reviewId)
      .query(
        `SELECT COUNT(*) AS HelpfulCount
         FROM dbo.ReviewHelpfulVotes
         WHERE ReviewId = @reviewId`,
      );

    res.json({
      ok: true,
      helpfulCount: Number(countResult.recordset[0]?.HelpfulCount || 0),
      isHelpful: exists.recordset.length === 0,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/reviews/helpful", async (req, res) => {
  try {
    const limit = Math.max(1, Math.min(50, Number(req.query.limit || 10)));
    await ensureProductReviewsTable();
    await ensureReviewHelpfulVotesTable();

    const pool = await getPool();
    const result = await pool
      .request()
      .input("limit", sql.Int, limit)
      .query(
        `SELECT TOP (@limit)
                pr.Id, pr.ProductId, pr.UserId, pr.Rating, pr.Comment, pr.CreatedAt,
                u.FullName AS UserName,
                p.Name AS ProductName,
                COUNT(hv.Id) AS HelpfulCount
         FROM dbo.ProductReviews pr
         INNER JOIN dbo.Users u ON u.Id = pr.UserId
         INNER JOIN dbo.Products p ON p.Id = pr.ProductId
         LEFT JOIN dbo.ReviewHelpfulVotes hv ON hv.ReviewId = pr.Id
         GROUP BY pr.Id, pr.ProductId, pr.UserId, pr.Rating, pr.Comment, pr.CreatedAt, u.FullName, p.Name
         ORDER BY COUNT(hv.Id) DESC, pr.CreatedAt DESC`,
      );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/notifications", requireAuth, async (req, res) => {
  try {
    await ensureNotificationsTable();
    const userId = String(req.user?.sub || "").trim();
    const pool = await getPool();
    const result = await pool
      .request()
      .input("userId", sql.UniqueIdentifier, userId)
      .query(
        `SELECT Id, UserId, [Type], Title, [Message], RefId, IsRead, CreatedAt, ReadAt
         FROM dbo.UserNotifications
         WHERE UserId = @userId
         ORDER BY CreatedAt DESC`,
      );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch("/api/notifications/:id/read", requireAuth, async (req, res) => {
  try {
    await ensureNotificationsTable();
    const { id } = req.params;
    const userId = String(req.user?.sub || "").trim();
    const pool = await getPool();
    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .input("userId", sql.UniqueIdentifier, userId)
      .query(
        `UPDATE dbo.UserNotifications
         SET IsRead = 1,
             ReadAt = SYSUTCDATETIME()
         WHERE Id = @id
           AND UserId = @userId`,
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch("/api/notifications/read-all", requireAuth, async (req, res) => {
  try {
    await ensureNotificationsTable();
    const userId = String(req.user?.sub || "").trim();
    const pool = await getPool();
    await pool
      .request()
      .input("userId", sql.UniqueIdentifier, userId)
      .query(
        `UPDATE dbo.UserNotifications
         SET IsRead = 1,
             ReadAt = SYSUTCDATETIME()
         WHERE UserId = @userId
           AND IsRead = 0`,
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/discounts", async (_req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      `SELECT Id, Code, [Percent], MinOrderValue, StartDate, EndDate
       FROM dbo.DiscountCodes
       WHERE IsActive = 1
       ORDER BY StartDate DESC`,
    );
    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/discounts", async (req, res) => {
  try {
    const { id, code, percent, minOrderValue, startDate, endDate } = req.body;
    const pool = await getPool();

    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .input("code", sql.NVarChar(40), code)
      .input("percent", sql.Decimal(5, 2), Number(percent || 0))
      .input("minOrderValue", sql.Decimal(18, 2), Number(minOrderValue || 0))
      .input("startDate", sql.DateTime2, new Date(startDate))
      .input("endDate", sql.DateTime2, new Date(endDate))
      .query(
        `INSERT INTO dbo.DiscountCodes(Id, Code, [Percent], MinOrderValue, StartDate, EndDate, IsActive)
         VALUES(@id, @code, @percent, @minOrderValue, @startDate, @endDate, 1)`,
      );

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/users", async (_req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      `SELECT Id, FullName, Email, Phone, Role, IsActive
       FROM dbo.Users
       ORDER BY CreatedAt DESC`,
    );
    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get("/api/admin/revenue-by-owner", async (_req, res) => {
  try {
    await ensureProductOwnerColumn();
    const pool = await getPool();
    const result = await pool.request().query(
      `SELECT
          u.Id AS OwnerId,
          u.FullName AS OwnerName,
          u.Email AS OwnerEmail,
          COUNT(DISTINCT p.Id) AS ProductCount,
          COUNT(DISTINCT CASE
              WHEN LOWER(o.PaymentStatus) = 'paid' AND LOWER(o.[Status]) <> 'cancelled'
              THEN o.Id
          END) AS PaidOrders,
          COALESCE(SUM(CASE
              WHEN LOWER(o.[Status]) <> 'cancelled'
              THEN oi.Quantity
              ELSE 0
          END), 0) AS ItemsSold,
          COALESCE(SUM(CASE
              WHEN LOWER(o.PaymentStatus) = 'paid' AND LOWER(o.[Status]) <> 'cancelled'
              THEN oi.LineTotal
              ELSE 0
          END), 0) AS Revenue
       FROM dbo.Users u
       LEFT JOIN dbo.Products p
           ON p.OwnerId = u.Id
          AND p.IsActive = 1
       LEFT JOIN dbo.OrderItems oi
           ON oi.ProductId = p.Id
       LEFT JOIN dbo.Orders o
           ON o.Id = oi.OrderId
       WHERE u.Role = 'owner'
       GROUP BY u.Id, u.FullName, u.Email
       ORDER BY Revenue DESC, OwnerName ASC`,
    );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/users", async (req, res) => {
  try {
    const { id, fullName, email, phone, role, isActive = true } = req.body;
    const pool = await getPool();

    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .input("fullName", sql.NVarChar(120), fullName)
      .input("email", sql.NVarChar(150), email)
      .input("phone", sql.NVarChar(20), phone || null)
      .input("role", sql.NVarChar(20), role)
      .input("isActive", sql.Bit, isActive)
      .query(
        `INSERT INTO dbo.Users(Id, FullName, Email, Phone, Role, IsActive)
         VALUES(@id, @fullName, @email, @phone, @role, @isActive)`,
      );

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.put("/api/users/:id", async (req, res) => {
  try {
    const { id } = req.params;
    const { fullName, email, phone, role, isActive } = req.body;
    const pool = await getPool();

    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .input("fullName", sql.NVarChar(120), fullName)
      .input("email", sql.NVarChar(150), email)
      .input("phone", sql.NVarChar(20), phone || null)
      .input("role", sql.NVarChar(20), role)
      .input("isActive", sql.Bit, isActive)
      .query(
        `UPDATE dbo.Users
         SET FullName=@fullName, Email=@email, Phone=@phone,
             Role=@role, IsActive=@isActive, UpdatedAt=SYSUTCDATETIME()
         WHERE Id=@id`,
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch("/api/users/:id/toggle-active", async (req, res) => {
  try {
    const { id } = req.params;
    const pool = await getPool();

    await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .query(
        `UPDATE dbo.Users
         SET IsActive = CASE WHEN IsActive = 1 THEN 0 ELSE 1 END,
             UpdatedAt = SYSUTCDATETIME()
         WHERE Id = @id`,
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get(
  "/api/admin/dashboard",
  requireAuth,
  requireAdmin,
  async (_req, res) => {
    try {
      const pool = await getPool();
      const result = await pool.request().query(
        `SELECT
        (SELECT COUNT(*) FROM dbo.Users WHERE IsActive = 1) AS TotalUsers,
        (SELECT COUNT(*) FROM dbo.Products WHERE IsActive = 1) AS TotalProducts,
        (SELECT COUNT(*) FROM dbo.Orders) AS TotalOrders,
        (SELECT COUNT(*) FROM dbo.Orders WHERE LOWER([Status]) = 'processing') AS ProcessingOrders,
        (SELECT COALESCE(SUM(CASE
          WHEN LOWER(PaymentStatus) = 'paid' AND LOWER([Status]) <> 'cancelled'
          THEN Total ELSE 0 END), 0)
         FROM dbo.Orders) AS TotalRevenue`,
      );

      const row = result.recordset[0] || {};
      res.json({
        totalUsers: Number(row.TotalUsers || 0),
        totalProducts: Number(row.TotalProducts || 0),
        totalOrders: Number(row.TotalOrders || 0),
        processingOrders: Number(row.ProcessingOrders || 0),
        totalRevenue: Number(row.TotalRevenue || 0),
      });
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  },
);

app.get("/api/admin/orders", requireAuth, requireAdmin, async (_req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      `SELECT o.Id, o.OrderCode, o.UserId, o.ShippingAddress, o.PaymentMethod,
              o.PaymentStatus, o.[Status], o.Subtotal, o.DiscountAmount, o.Total,
              o.CreatedAt, u.FullName AS CustomerName, u.Email AS CustomerEmail,
              COUNT(oi.ProductId) AS ItemCount
       FROM dbo.Orders o
       INNER JOIN dbo.Users u ON u.Id = o.UserId
       LEFT JOIN dbo.OrderItems oi ON oi.OrderId = o.Id
       GROUP BY o.Id, o.OrderCode, o.UserId, o.ShippingAddress, o.PaymentMethod,
                o.PaymentStatus, o.[Status], o.Subtotal, o.DiscountAmount, o.Total,
                o.CreatedAt, u.FullName, u.Email
       ORDER BY o.CreatedAt DESC`,
    );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch(
  "/api/admin/orders/:id/status",
  requireAuth,
  requireAdmin,
  async (req, res) => {
    try {
      const { id } = req.params;
      const { status, paymentStatus } = req.body;
      const normalizedStatus = String(status || "")
        .trim()
        .toLowerCase();
      const normalizedPaymentStatus = String(paymentStatus || "")
        .trim()
        .toLowerCase();

      if (
        normalizedStatus &&
        !["processing", "delivered", "cancelled"].includes(normalizedStatus)
      ) {
        return res.status(400).json({ message: "Invalid order status" });
      }
      if (
        normalizedPaymentStatus &&
        !["pending", "paid", "failed"].includes(normalizedPaymentStatus)
      ) {
        return res.status(400).json({ message: "Invalid payment status" });
      }

      const pool = await getPool();
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .input("status", sql.NVarChar(20), normalizedStatus || null)
        .input(
          "paymentStatus",
          sql.NVarChar(20),
          normalizedPaymentStatus || null,
        )
        .query(
          `UPDATE dbo.Orders
         SET [Status] = COALESCE(@status, [Status]),
             PaymentStatus = COALESCE(@paymentStatus, PaymentStatus)
         WHERE Id = @id`,
        );

      res.json({ ok: true });
    } catch (error) {
      res.status(500).json({ message: error.message });
    }
  },
);

app.get("/api/orders", async (req, res) => {
  try {
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const role = String(payload?.role || "").toLowerCase();
    const isOwner = role === "owner";
    const isCustomer = role === "customer";
    const ownerId = isOwner ? String(payload?.sub || "") : null;
    const customerId = isCustomer ? String(payload?.sub || "") : null;

    const pool = await getPool();

    const ordersRequest = pool.request();
    if (isCustomer) {
      ordersRequest.input("customerId", sql.UniqueIdentifier, customerId);
    }

    const ordersResult = await ordersRequest.query(
      `SELECT o.Id, o.OrderCode, o.UserId, o.ShippingAddress, o.PaymentMethod,
              o.PaymentStatus, o.[Status], o.CreatedAt
       FROM dbo.Orders o
       ${isCustomer ? "WHERE o.UserId = @customerId" : ""}
       ORDER BY o.CreatedAt DESC`,
    );

    const itemsRequest = pool.request();
    if (isOwner) {
      itemsRequest.input("ownerId", sql.UniqueIdentifier, ownerId);
    }

    const itemsResult = await itemsRequest.query(
      `SELECT oi.OrderId, oi.ProductId, oi.SizeLabel, oi.Quantity, oi.UnitPrice,
              p.Name, p.Category, p.[Description], p.DiscountPercent,
              COALESCE(
                NULLIF(
                  (
                    SELECT TOP 1 pi.ImageUrl
                    FROM dbo.ProductImages pi
                    WHERE pi.ProductId = p.Id
                    ORDER BY pi.SortOrder ASC, pi.Id ASC
                  ),
                  ''
                ),
                'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=800'
              ) AS ImageUrl
       FROM dbo.OrderItems oi
            INNER JOIN dbo.Products p ON p.Id = oi.ProductId
            ${isOwner ? "WHERE p.OwnerId = @ownerId" : ""}`,
    );

    const itemsByOrder = new Map();
    for (const item of itemsResult.recordset) {
      if (!itemsByOrder.has(item.OrderId)) itemsByOrder.set(item.OrderId, []);
      itemsByOrder.get(item.OrderId).push(item);
    }

    const mapped = ordersResult.recordset
      .map((order) => ({
        ...order,
        items: itemsByOrder.get(order.Id) || [],
      }))
      .filter((order) => {
        if (!isOwner) return true;
        return order.items.length > 0;
      });

    res.json(mapped);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post("/api/orders", async (req, res) => {
  const transaction = new sql.Transaction(await getPool());
  try {
    const {
      orderCode,
      userId,
      shippingAddress,
      paymentMethod,
      paymentStatus,
      status,
      subtotal,
      discountAmount,
      total,
      items,
    } = req.body;

    await transaction.begin();

    const orderReq = new sql.Request(transaction);
    const orderId = req.body.id;

    await orderReq
      .input("id", sql.UniqueIdentifier, orderId)
      .input("orderCode", sql.NVarChar(30), orderCode)
      .input("userId", sql.UniqueIdentifier, userId)
      .input("shippingAddress", sql.NVarChar(500), shippingAddress)
      .input("paymentMethod", sql.NVarChar(20), paymentMethod)
      .input("paymentStatus", sql.NVarChar(20), paymentStatus)
      .input("status", sql.NVarChar(20), status)
      .input("subtotal", sql.Decimal(18, 2), Number(subtotal || 0))
      .input("discountAmount", sql.Decimal(18, 2), Number(discountAmount || 0))
      .input("total", sql.Decimal(18, 2), Number(total || 0))
      .query(
        `INSERT INTO dbo.Orders(Id, OrderCode, UserId, ShippingAddress, PaymentMethod, PaymentStatus, [Status], Subtotal, DiscountAmount, Total)
         VALUES(@id, @orderCode, @userId, @shippingAddress, @paymentMethod, @paymentStatus, @status, @subtotal, @discountAmount, @total)`,
      );

    for (const item of items || []) {
      const quantity = Number(item.quantity || 1);
      const sizeLabel = String(item.sizeLabel || "")
        .trim()
        .toUpperCase();
      const colorHexRaw = String(item.colorHex || "")
        .trim()
        .toUpperCase();
      const colorHex =
        colorHexRaw.length === 0
          ? null
          : colorHexRaw.startsWith("#")
            ? colorHexRaw
            : `#${colorHexRaw}`;

      if (!item.productId || !sizeLabel || quantity <= 0) {
        throw new Error("Invalid order item payload");
      }

      const reserveReq = new sql.Request(transaction);
      reserveReq
        .input("productId", sql.UniqueIdentifier, item.productId)
        .input("sizeLabel", sql.NVarChar(10), sizeLabel)
        .input("quantity", sql.Int, quantity);

      let reserveResult;
      if (colorHex) {
        reserveReq.input("colorHex", sql.NVarChar(10), colorHex);
        reserveResult = await reserveReq.query(
          `UPDATE pv
           SET pv.Stock = pv.Stock - @quantity
           OUTPUT INSERTED.ColorHex AS ReservedColorHex
           FROM dbo.ProductVariants pv
           WHERE pv.ProductId = @productId
             AND UPPER(pv.SizeLabel) = @sizeLabel
             AND UPPER(pv.ColorHex) = @colorHex
             AND pv.Stock >= @quantity`,
        );
      } else {
        reserveResult = await reserveReq.query(
          `UPDATE pv
           SET pv.Stock = pv.Stock - @quantity
           OUTPUT INSERTED.ColorHex AS ReservedColorHex
           FROM dbo.ProductVariants pv
           WHERE pv.Id = (
             SELECT TOP 1 Id
             FROM dbo.ProductVariants
             WHERE ProductId = @productId
               AND UPPER(SizeLabel) = @sizeLabel
               AND Stock >= @quantity
             ORDER BY Stock DESC
           )`,
        );
      }

      if (!reserveResult.rowsAffected || reserveResult.rowsAffected[0] === 0) {
        throw new Error(
          `Insufficient stock for product ${item.productId}, size ${sizeLabel}`,
        );
      }
      const reservedColorHex =
        reserveResult.recordset[0]?.ReservedColorHex || colorHex;

      const syncProductStockReq = new sql.Request(transaction);
      await syncProductStockReq
        .input("productId", sql.UniqueIdentifier, item.productId)
        .query(
          `UPDATE dbo.Products
           SET Stock = ISNULL((
             SELECT SUM(Stock)
             FROM dbo.ProductVariants
             WHERE ProductId = @productId
           ), 0),
           UpdatedAt = SYSUTCDATETIME()
           WHERE Id = @productId`,
        );

      const itemReq = new sql.Request(transaction);
      await itemReq
        .input("orderId", sql.UniqueIdentifier, orderId)
        .input("productId", sql.UniqueIdentifier, item.productId)
        .input("sizeLabel", sql.NVarChar(10), sizeLabel)
        .input("colorHex", sql.NVarChar(10), reservedColorHex)
        .input("quantity", sql.Int, quantity)
        .input("unitPrice", sql.Decimal(18, 2), Number(item.unitPrice || 0))
        .input("lineTotal", sql.Decimal(18, 2), Number(item.lineTotal || 0))
        .query(
          `INSERT INTO dbo.OrderItems(OrderId, ProductId, SizeLabel, ColorHex, Quantity, UnitPrice, LineTotal)
           VALUES(@orderId, @productId, @sizeLabel, @colorHex, @quantity, @unitPrice, @lineTotal)`,
        );
    }

    await transaction.commit();
    res.status(201).json({ ok: true });
  } catch (error) {
    if (transaction._aborted === false) {
      await transaction.rollback();
    }
    res.status(500).json({ message: error.message });
  }
});

app.patch("/api/orders/:id/status", async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const normalizedStatus = String(status || "")
      .trim()
      .toLowerCase();
    if (!["processing", "delivered", "cancelled"].includes(normalizedStatus)) {
      return res.status(400).json({ message: "Invalid status" });
    }
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === "owner";
    const ownerId = isOwner ? String(payload.sub || "") : null;

    const pool = await getPool();

    if (isOwner) {
      const ownsOrder = await pool
        .request()
        .input("id", sql.UniqueIdentifier, id)
        .input("ownerId", sql.UniqueIdentifier, ownerId)
        .query(
          `SELECT TOP 1 o.Id
           FROM dbo.Orders o
           INNER JOIN dbo.OrderItems oi ON oi.OrderId = o.Id
           INNER JOIN dbo.Products p ON p.Id = oi.ProductId
           WHERE o.Id = @id AND p.OwnerId = @ownerId`,
        );

      if (ownsOrder.recordset.length === 0) {
        return res.status(403).json({ message: "Forbidden" });
      }
    }

    const currentOrderResult = await pool
      .request()
      .input("id", sql.UniqueIdentifier, id)
      .query(
        `SELECT TOP 1 Id, [Status]
         FROM dbo.Orders
         WHERE Id = @id`,
      );

    if (currentOrderResult.recordset.length === 0) {
      return res.status(404).json({ message: "Order not found" });
    }

    const previousStatus = String(
      currentOrderResult.recordset[0].Status || "",
    ).toLowerCase();
    const shouldRestoreStock =
      normalizedStatus === "cancelled" && previousStatus !== "cancelled";

    const transaction = new sql.Transaction(pool);
    await transaction.begin();

    try {
      await new sql.Request(transaction)
        .input("id", sql.UniqueIdentifier, id)
        .input("status", sql.NVarChar(20), normalizedStatus)
        .query(
          `UPDATE dbo.Orders
           SET [Status]=@status, UpdatedAt=SYSUTCDATETIME()
           WHERE Id=@id`,
        );

      if (shouldRestoreStock) {
        const itemsResult = await new sql.Request(transaction)
          .input("orderId", sql.UniqueIdentifier, id)
          .query(
            `SELECT ProductId, SizeLabel, ColorHex, Quantity
             FROM dbo.OrderItems
             WHERE OrderId = @orderId`,
          );

        const productIds = new Set();
        for (const item of itemsResult.recordset) {
          const productId = String(item.ProductId);
          const sizeLabel = String(item.SizeLabel || "")
            .trim()
            .toUpperCase();
          const colorHexRaw = String(item.ColorHex || "")
            .trim()
            .toUpperCase();
          const colorHex =
            colorHexRaw.length === 0
              ? null
              : colorHexRaw.startsWith("#")
                ? colorHexRaw
                : `#${colorHexRaw}`;
          const quantity = Number(item.Quantity || 0);

          if (!productId || !sizeLabel || quantity <= 0) {
            continue;
          }

          const restockReq = new sql.Request(transaction)
            .input("productId", sql.UniqueIdentifier, productId)
            .input("sizeLabel", sql.NVarChar(10), sizeLabel)
            .input("quantity", sql.Int, quantity);

          let restockResult;
          if (colorHex) {
            restockReq.input("colorHex", sql.NVarChar(10), colorHex);
            restockResult = await restockReq.query(
              `UPDATE dbo.ProductVariants
               SET Stock = Stock + @quantity
               WHERE ProductId = @productId
                 AND UPPER(SizeLabel) = @sizeLabel
                 AND UPPER(ColorHex) = @colorHex`,
            );
          } else {
            restockResult = await restockReq.query(
              `UPDATE dbo.ProductVariants
               SET Stock = Stock + @quantity
               WHERE Id = (
                 SELECT TOP 1 Id
                 FROM dbo.ProductVariants
                 WHERE ProductId = @productId
                   AND UPPER(SizeLabel) = @sizeLabel
                 ORDER BY Stock ASC
               )`,
            );
          }

          if (
            !restockResult.rowsAffected ||
            restockResult.rowsAffected[0] === 0
          ) {
            throw new Error(
              `Failed to restore stock for product ${productId}, size ${sizeLabel}`,
            );
          }

          productIds.add(productId);
        }

        for (const productId of productIds) {
          await new sql.Request(transaction)
            .input("productId", sql.UniqueIdentifier, productId)
            .query(
              `UPDATE dbo.Products
               SET Stock = ISNULL((
                 SELECT SUM(Stock)
                 FROM dbo.ProductVariants
                 WHERE ProductId = @productId
               ), 0),
               UpdatedAt = SYSUTCDATETIME()
               WHERE Id = @productId`,
            );
        }
      }

      await transaction.commit();
    } catch (error) {
      if (transaction._aborted === false) {
        await transaction.rollback();
      }
      throw error;
    }

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`API is running on http://localhost:${PORT}`);
  ensureOtpTable().catch((error) => {
    console.error("Failed to ensure UserOTP table:", error.message);
  });
});
