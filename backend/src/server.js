require("dotenv").config();
const express = require("express");
const cors = require("cors");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const bcrypt = require("bcryptjs");
const { sql, getPool } = require("./db");

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
    await ensureProductReviewsTable();

    const pool = await getPool();
    const result = await pool
      .request()
      .input("productId", sql.UniqueIdentifier, id)
      .query(
        `SELECT pr.Id, pr.ProductId, pr.UserId, pr.Rating, pr.Comment, pr.CreatedAt,
                u.FullName AS UserName
         FROM dbo.ProductReviews pr
         INNER JOIN dbo.Users u ON u.Id = pr.UserId
         WHERE pr.ProductId = @productId
         ORDER BY pr.CreatedAt DESC`,
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
      return res
        .status(403)
        .json({
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
    } else {
      await pool
        .request()
        .input("id", sql.UniqueIdentifier, createGuid())
        .input("productId", sql.UniqueIdentifier, id)
        .input("userId", sql.UniqueIdentifier, normalizedUserId)
        .input("rating", sql.Int, numericRating)
        .input("comment", sql.NVarChar(1000), normalizedComment)
        .query(
          `INSERT INTO dbo.ProductReviews(Id, ProductId, UserId, Rating, Comment)
           VALUES(@id, @productId, @userId, @rating, @comment)`,
        );
    }

    res.status(201).json({ ok: true });
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
});
