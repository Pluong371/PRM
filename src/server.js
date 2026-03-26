require('dotenv').config();
const fs = require('fs/promises');
const path = require('path');
const express = require('express');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { sql, getPool } = require('./db');

const app = express();
app.use(cors());
app.use(express.json({ limit: '25mb' }));
const MODEL_IMAGES_DIR = path.join(__dirname, '..', 'molde');
app.use('/api/model-images', express.static(MODEL_IMAGES_DIR));

const PORT = Number(process.env.PORT || 3000);
const JWT_SECRET = process.env.JWT_SECRET || 'clothing-store-dev-secret';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';
const FASHN_API_KEY = String(process.env.FASHN_API_KEY || '').trim();
const FASHN_API_BASE_URL = String(process.env.FASHN_API_BASE_URL || 'https://api.fashn.ai/v1').trim();

const ALLOWED_TRYON_CATEGORIES = new Set(['auto', 'tops', 'bottoms', 'one-pieces']);
const ALLOWED_TRYON_MODES = new Set(['performance', 'balanced', 'quality']);

function isHttpUrl(value) {
  if (typeof value !== 'string') return false;
  const normalized = value.trim();
  return normalized.startsWith('http://') || normalized.startsWith('https://');
}

function isBase64DataImage(value) {
  if (typeof value !== 'string') return false;
  return /^data:image\/(png|jpe?g|webp);base64,/i.test(value.trim());
}

function isSupportedTryOnImage(value) {
  return isHttpUrl(value) || isBase64DataImage(value);
}

function isLikelyLocalFilePath(value) {
  if (typeof value !== 'string') return false;
  const normalized = value.trim();
  if (!normalized) return false;
  if (normalized.startsWith('file://')) return true;
  if (/^[a-zA-Z]:\\/.test(normalized)) return true;
  if (normalized.startsWith('\\')) return true;
  if (normalized.startsWith('./') || normalized.startsWith('../')) return true;
  return normalized.startsWith('/');
}

function normalizeLocalFilePath(value) {
  const normalized = String(value || '').trim();
  if (!normalized) return '';
  if (normalized.startsWith('file://')) {
    return path.normalize(new URL(normalized).pathname.replace(/^\/+/, ''));
  }
  return path.resolve(normalized);
}

function mimeTypeFromPath(filePath) {
  const ext = path.extname(filePath).toLowerCase();
  if (ext === '.png') return 'image/png';
  if (ext === '.webp') return 'image/webp';
  return 'image/jpeg';
}

async function normalizeTryOnImageInput(value) {
  const normalized = String(value || '').trim();
  if (!normalized) {
    throw new Error('Image input is empty');
  }
  if (isHttpUrl(normalized) || isBase64DataImage(normalized)) {
    return normalized;
  }
  if (!isLikelyLocalFilePath(normalized)) {
    throw new Error('Image must be a public URL, base64 data URI, or local file path');
  }

  const resolvedPath = normalizeLocalFilePath(normalized);
  await fs.access(resolvedPath);
  const bytes = await fs.readFile(resolvedPath);
  const mimeType = mimeTypeFromPath(resolvedPath);
  return `data:${mimeType};base64,${bytes.toString('base64')}`;
}

function normalizeTryOnCategory(value) {
  const normalized = String(value || 'auto').trim().toLowerCase();
  return ALLOWED_TRYON_CATEGORIES.has(normalized) ? normalized : 'auto';
}

function normalizeTryOnMode(value) {
  const normalized = String(value || 'balanced').trim().toLowerCase();
  return ALLOWED_TRYON_MODES.has(normalized) ? normalized : 'balanced';
}

async function fetchJsonWithTimeout(url, options = {}, timeoutMs = 20000) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), timeoutMs);

  try {
    const response = await fetch(url, {
      ...options,
      signal: controller.signal,
    });
    let payload = null;
    try {
      payload = await response.json();
    } catch (_error) {
      payload = null;
    }
    return {
      ok: response.ok,
      status: response.status,
      headers: response.headers,
      payload,
    };
  } finally {
    clearTimeout(timeout);
  }
}

async function runFashnTryOn({
  modelImage,
  garmentImage,
  category = 'auto',
  mode = 'balanced',
  outputFormat = 'jpeg',
  pollIntervalMs = 1500,
  maxPollMs = 70000,
}) {
  if (!FASHN_API_KEY) {
    throw new Error('Missing FASHN_API_KEY in backend environment');
  }
  if (typeof fetch !== 'function') {
    throw new Error('Node runtime does not support global fetch. Please use Node.js 18+');
  }

  const runResult = await fetchJsonWithTimeout(
    `${FASHN_API_BASE_URL}/run`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${FASHN_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model_name: 'tryon-v1.6',
        inputs: {
          model_image: modelImage,
          garment_image: garmentImage,
          category: normalizeTryOnCategory(category),
          mode: normalizeTryOnMode(mode),
          output_format: outputFormat,
        },
      }),
    },
    20000
  );

  if (!runResult.ok) {
    const message = runResult?.payload?.message
      || runResult?.payload?.error
      || `FASHN run request failed (${runResult.status})`;
    throw new Error(String(message));
  }

  const predictionId = String(runResult?.payload?.id || '').trim();
  if (!predictionId) {
    throw new Error('FASHN response did not return prediction id');
  }

  const startedAt = Date.now();
  while (Date.now() - startedAt <= maxPollMs) {
    const statusResult = await fetchJsonWithTimeout(
      `${FASHN_API_BASE_URL}/status/${encodeURIComponent(predictionId)}`,
      {
        method: 'GET',
        headers: {
          Authorization: `Bearer ${FASHN_API_KEY}`,
        },
      },
      20000
    );

    if (!statusResult.ok) {
      const message = statusResult?.payload?.message
        || statusResult?.payload?.error
        || `FASHN status request failed (${statusResult.status})`;
      throw new Error(String(message));
    }

    const statusPayload = statusResult.payload || {};
    const status = String(statusPayload.status || '').toLowerCase();

    if (status === 'completed') {
      const output = Array.isArray(statusPayload.output)
        ? statusPayload.output.filter((value) => typeof value === 'string' && value.trim().length > 0)
        : [];
      const creditsUsedHeader = statusResult.headers.get('x-fashn-credits-used');
      return {
        id: predictionId,
        output,
        creditsUsed: Number(creditsUsedHeader || 0) || 0,
      };
    }

    if (status === 'failed') {
      const message = statusPayload?.error?.message
        || statusPayload?.error?.name
        || 'Try-on prediction failed';
      throw new Error(String(message));
    }

    await new Promise((resolve) => setTimeout(resolve, pollIntervalMs));
  }

  throw new Error('Try-on timed out while waiting for FASHN status');
}

function issueToken(user) {
  return jwt.sign(
    {
      sub: user.Id,
      role: user.Role,
      email: user.Email,
    },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRES_IN }
  );
}

function getBearerToken(req) {
  const authHeader = String(req.headers.authorization || '');
  if (!authHeader.toLowerCase().startsWith('bearer ')) return null;
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
     END`
  );
}

function createGuid() {
  if (typeof crypto.randomUUID === 'function') {
    return crypto.randomUUID();
  }
  const bytes = crypto.randomBytes(16);
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  const hex = bytes.toString('hex');
  return `${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}`;
}

function normalizeImageUrls(body) {
  const fromArray = Array.isArray(body.imageUrls)
    ? body.imageUrls
    : [];
  const fromSingle = body.imageUrl ? [body.imageUrl] : [];

  const normalized = [...fromArray, ...fromSingle]
    .map((value) => String(value || '').trim())
    .filter((value) => value.length > 0);

  return [...new Set(normalized)];
}

function normalizeSizeStocks(body) {
  const raw = body?.sizeStocks;
  if (!raw || typeof raw !== 'object') return {};

  const result = {};
  for (const [sizeRaw, stockRaw] of Object.entries(raw)) {
    const size = String(sizeRaw || '').trim().toUpperCase();
    if (!size) continue;
    const stock = Number(stockRaw || 0);
    result[size] = Number.isFinite(stock) ? Math.max(0, Math.trunc(stock)) : 0;
  }
  return result;
}

function normalizeColorImages(body) {
  const raw = body?.colorImages;
  if (!raw || typeof raw !== 'object') return {};

  const result = {};
  for (const [hexRaw, imagesRaw] of Object.entries(raw)) {
    const hex = String(hexRaw || '').trim().toUpperCase();
    if (!hex) continue;
    const normalizedHex = hex.startsWith('#') ? hex : `#${hex}`;
    const images = Array.isArray(imagesRaw)
      ? imagesRaw
      : [imagesRaw];
    result[normalizedHex] = [...new Set(
      images
        .map((value) => String(value || '').trim())
        .filter((value) => value.length > 0)
    )];
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
     END`
  );
}

async function ensureProductOwnerColumn() {
  const pool = await getPool();
  await pool.request().query(
    `IF COL_LENGTH('dbo.Products', 'OwnerId') IS NULL
     BEGIN
       ALTER TABLE dbo.Products
       ADD OwnerId UNIQUEIDENTIFIER NULL;
     END`
  );
}

app.get('/api/health', async (_req, res) => {
  try {
    const pool = await getPool();
    await pool.request().query('SELECT 1 AS ok');
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: 'Email and password are required' });
    }

    const pool = await getPool();

    const result = await pool
      .request()
      .input('email', sql.NVarChar(150), email)
      .input('password', sql.NVarChar(255), password)
      .query(
        `SELECT TOP 1 Id, FullName, Email, Phone, Role, IsActive
         FROM dbo.Users
         WHERE Email = @email
           AND IsActive = 1
           AND PasswordHash = @password`
      );

    if (result.recordset.length === 0) {
      return res.status(401).json({ message: 'Invalid credentials' });
    }

    const user = result.recordset[0];
    const token = issueToken(user);

    res.json({ token, user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/api/auth/register', async (req, res) => {
  try {
    const { fullName, email, phone, password } = req.body;

    if (!fullName || !email || !password) {
      return res
        .status(400)
        .json({ message: 'Full name, email and password are required' });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const pool = await getPool();

    const existed = await pool
      .request()
      .input('email', sql.NVarChar(150), normalizedEmail)
      .query(`SELECT TOP 1 Id FROM dbo.Users WHERE Email = @email`);

    if (existed.recordset.length > 0) {
      return res.status(409).json({ message: 'Email already exists' });
    }

    const created = await pool
      .request()
      .input('fullName', sql.NVarChar(120), String(fullName).trim())
      .input('email', sql.NVarChar(150), normalizedEmail)
      .input('phone', sql.NVarChar(20), phone || null)
      .input('password', sql.NVarChar(255), String(password))
      .query(
        `INSERT INTO dbo.Users(FullName, Email, Phone, PasswordHash, Role, IsActive)
         OUTPUT INSERTED.Id, INSERTED.FullName, INSERTED.Email, INSERTED.Phone, INSERTED.Role, INSERTED.IsActive
         VALUES(@fullName, @email, @phone, @password, 'customer', 1)`
      );

    const user = created.recordset[0];
    const token = issueToken(user);

    res.status(201).json({ token, user });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/auth/me', async (req, res) => {
  try {
    const payload = getTokenPayload(req);
    if (!payload?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const pool = await getPool();
    const result = await pool
      .request()
      .input('id', sql.UniqueIdentifier, String(payload.sub))
      .query(
        `SELECT TOP 1 Id, FullName, Email, Phone, Role, IsActive
         FROM dbo.Users
         WHERE Id = @id AND IsActive = 1`
      );

    if (result.recordset.length === 0) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    res.json(result.recordset[0]);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/products', async (req, res) => {
  try {
    await ensureProductImagesColorColumn();
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === 'owner';
    const ownerId = isOwner ? String(payload.sub || '') : null;
    const pool = await getPool();
    const productsRequest = pool.request();
    if (isOwner) {
      productsRequest.input('ownerId', sql.UniqueIdentifier, ownerId);
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
         ${isOwner ? 'AND p.OwnerId = @ownerId' : ''}
       ORDER BY CreatedAt DESC`
    );

    const imagesResult = await pool.request().query(
      `SELECT pi.ProductId, pi.ImageUrl, pi.ColorHex, pi.SortOrder, pi.Id
       FROM dbo.ProductImages pi
       INNER JOIN dbo.Products p ON p.Id = pi.ProductId
       WHERE p.IsActive = 1
       ORDER BY pi.ProductId ASC, pi.SortOrder ASC, pi.Id ASC`
    );

    const variantsResult = await pool.request().query(
      `SELECT pv.ProductId, pv.SizeLabel, pv.Stock, pv.ColorHex
       FROM dbo.ProductVariants pv
       INNER JOIN dbo.Products p ON p.Id = pv.ProductId
       WHERE p.IsActive = 1
       ORDER BY pv.ProductId ASC, pv.SizeLabel ASC`
    );

    const imagesByProduct = new Map();
    const colorImagesByProduct = new Map();
    for (const row of imagesResult.recordset) {
      const key = String(row.ProductId).toLowerCase();
      if (!imagesByProduct.has(key)) {
        imagesByProduct.set(key, []);
      }
      imagesByProduct.get(key).push(row.ImageUrl);

      const colorHex = String(row.ColorHex || '').trim().toUpperCase();
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
      const size = String(row.SizeLabel || '').trim().toUpperCase();
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

app.post('/api/products', async (req, res) => {
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
        .map((value) => String(value || '').trim().toUpperCase())
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
      colorImages = { '#000000': imageUrls };
    }

    const stockFromSizes = Object.values(sizeStocks).reduce(
      (sum, value) => sum + Number(value || 0),
      0
    );
    const finalStock = Object.keys(sizeStocks).length > 0
      ? stockFromSizes
      : Number(stock || 0);
    const finalOwnerId = payload?.role === 'owner'
      ? String(payload.sub || '')
      : (ownerId || null);

    const pool = await getPool();

    await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .input('ownerId', sql.UniqueIdentifier, finalOwnerId || null)
      .input('name', sql.NVarChar(200), name)
      .input('category', sql.NVarChar(80), category)
      .input('description', sql.NVarChar(sql.MAX), description || '')
      .input('price', sql.Decimal(18, 2), Number(price || 0))
      .input('discountPercent', sql.Decimal(5, 2), Number(discountPercent || 0))
      .input('stock', sql.Int, finalStock)
      .query(
        `INSERT INTO dbo.Products(Id, OwnerId, Name, Category, [Description], Price, DiscountPercent, Stock, IsActive)
        VALUES(@id, @ownerId, @name, @category, @description, @price, @discountPercent, @stock, 1)`
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
          .input('productId', sql.UniqueIdentifier, id)
          .input('imageUrl', sql.NVarChar(500), imageUrl)
          .input('colorHex', sql.NVarChar(10), colorHex)
          .input('sortOrder', sql.Int, sortOrder)
          .query(
            `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
             VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`
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
        .input('productId', sql.UniqueIdentifier, id)
        .input('imageUrl', sql.NVarChar(500), imageUrl)
        .input('colorHex', sql.NVarChar(10), null)
        .input('sortOrder', sql.Int, sortOrder)
        .query(
          `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
           VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`
        );
      sortOrder += 1;
    }

    const variantColor = Object.keys(colorImages)[0] || '#000000';
    for (const [size, stockValue] of Object.entries(sizeStocks)) {
      await pool
        .request()
        .input('id', sql.UniqueIdentifier, createGuid())
        .input('productId', sql.UniqueIdentifier, id)
        .input('sizeLabel', sql.NVarChar(10), size)
        .input('colorHex', sql.NVarChar(10), variantColor)
        .input('stock', sql.Int, Number(stockValue || 0))
        .query(
          `INSERT INTO dbo.ProductVariants(Id, ProductId, SizeLabel, ColorHex, Stock)
           VALUES(@id, @productId, @sizeLabel, @colorHex, @stock)`
        );
    }

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.put('/api/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    await ensureProductImagesColorColumn();
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === 'owner';
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
        .map((value) => String(value || '').trim().toUpperCase())
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
      colorImages = { '#000000': imageUrls };
    }

    const stockFromSizes = Object.values(sizeStocks).reduce(
      (sum, value) => sum + Number(value || 0),
      0
    );
    const finalStock = Object.keys(sizeStocks).length > 0
      ? stockFromSizes
      : Number(stock || 0);

    const pool = await getPool();

    if (isOwner) {
      const owned = await pool
        .request()
        .input('id', sql.UniqueIdentifier, id)
        .input('ownerId', sql.UniqueIdentifier, String(payload.sub || ''))
        .query(
          `SELECT TOP 1 Id
           FROM dbo.Products
           WHERE Id = @id AND OwnerId = @ownerId AND IsActive = 1`
        );

      if (owned.recordset.length === 0) {
        return res.status(403).json({ message: 'Forbidden' });
      }
    }

    const finalOwnerId = isOwner
      ? String(payload.sub || '')
      : (ownerId || null);

    await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .input('ownerId', sql.UniqueIdentifier, finalOwnerId)
      .input('name', sql.NVarChar(200), name)
      .input('category', sql.NVarChar(80), category)
      .input('description', sql.NVarChar(sql.MAX), description || '')
      .input('price', sql.Decimal(18, 2), Number(price || 0))
      .input('discountPercent', sql.Decimal(5, 2), Number(discountPercent || 0))
      .input('stock', sql.Int, finalStock)
      .query(
        `UPDATE dbo.Products
         SET OwnerId=COALESCE(@ownerId, OwnerId),
           Name=@name, Category=@category, [Description]=@description,
             Price=@price, DiscountPercent=@discountPercent, Stock=@stock,
             UpdatedAt=SYSUTCDATETIME()
         WHERE Id=@id`
      );

    await pool
      .request()
      .input('productId', sql.UniqueIdentifier, id)
      .query(`DELETE FROM dbo.ProductImages WHERE ProductId=@productId`);

    await pool
      .request()
      .input('productId', sql.UniqueIdentifier, id)
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
          .input('productId', sql.UniqueIdentifier, id)
          .input('imageUrl', sql.NVarChar(500), imageUrl)
          .input('colorHex', sql.NVarChar(10), colorHex)
          .input('sortOrder', sql.Int, sortOrder)
          .query(
            `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
             VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`
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
        .input('productId', sql.UniqueIdentifier, id)
        .input('imageUrl', sql.NVarChar(500), imageUrl)
        .input('colorHex', sql.NVarChar(10), null)
        .input('sortOrder', sql.Int, sortOrder)
        .query(
          `INSERT INTO dbo.ProductImages(ProductId, ImageUrl, ColorHex, SortOrder)
           VALUES(@productId, @imageUrl, @colorHex, @sortOrder)`
        );
      sortOrder += 1;
    }

    const variantColor = Object.keys(colorImages)[0] || '#000000';
    for (const [size, stockValue] of Object.entries(sizeStocks)) {
      await pool
        .request()
        .input('id', sql.UniqueIdentifier, createGuid())
        .input('productId', sql.UniqueIdentifier, id)
        .input('sizeLabel', sql.NVarChar(10), size)
        .input('colorHex', sql.NVarChar(10), variantColor)
        .input('stock', sql.Int, Number(stockValue || 0))
        .query(
          `INSERT INTO dbo.ProductVariants(Id, ProductId, SizeLabel, ColorHex, Stock)
           VALUES(@id, @productId, @sizeLabel, @colorHex, @stock)`
        );
    }

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.delete('/api/products/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === 'owner';
    const pool = await getPool();

    if (isOwner) {
      const owned = await pool
        .request()
        .input('id', sql.UniqueIdentifier, id)
        .input('ownerId', sql.UniqueIdentifier, String(payload.sub || ''))
        .query(
          `SELECT TOP 1 Id
           FROM dbo.Products
           WHERE Id = @id AND OwnerId = @ownerId AND IsActive = 1`
        );

      if (owned.recordset.length === 0) {
        return res.status(403).json({ message: 'Forbidden' });
      }
    }

    await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .query(
        `UPDATE dbo.Products SET IsActive = 0, UpdatedAt=SYSUTCDATETIME() WHERE Id=@id`
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/products/:id/reviews', async (req, res) => {
  try {
    const { id } = req.params;
    await ensureProductReviewsTable();

    const pool = await getPool();
    const result = await pool
      .request()
      .input('productId', sql.UniqueIdentifier, id)
      .query(
        `SELECT pr.Id, pr.ProductId, pr.UserId, pr.Rating, pr.Comment, pr.CreatedAt,
                u.FullName AS UserName
         FROM dbo.ProductReviews pr
         INNER JOIN dbo.Users u ON u.Id = pr.UserId
         WHERE pr.ProductId = @productId
         ORDER BY pr.CreatedAt DESC`
      );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/products/:id/can-review', async (req, res) => {
  try {
    const { id } = req.params;
    const userId = String(req.query.userId || '').trim();
    if (!userId) {
      return res.status(400).json({ message: 'userId is required' });
    }

    await ensureProductReviewsTable();

    const pool = await getPool();
    const purchasedResult = await pool
      .request()
      .input('productId', sql.UniqueIdentifier, id)
      .input('userId', sql.UniqueIdentifier, userId)
      .query(
        `SELECT TOP 1 1 AS Purchased
         FROM dbo.OrderItems oi
         INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
         WHERE oi.ProductId = @productId
           AND o.UserId = @userId
           AND LOWER(o.[Status]) <> 'cancelled'`
      );

    const reviewedResult = await pool
      .request()
      .input('productId', sql.UniqueIdentifier, id)
      .input('userId', sql.UniqueIdentifier, userId)
      .query(
        `SELECT TOP 1 1 AS Reviewed
         FROM dbo.ProductReviews
         WHERE ProductId = @productId
           AND UserId = @userId`
      );

    res.json({
      canReview: purchasedResult.recordset.length > 0,
      hasReviewed: reviewedResult.recordset.length > 0,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/api/products/:id/reviews', async (req, res) => {
  try {
    const { id } = req.params;
    const { userId, rating, comment } = req.body;

    const normalizedUserId = String(userId || '').trim();
    const normalizedComment = String(comment || '').trim();
    const numericRating = Number(rating || 0);

    if (!normalizedUserId) {
      return res.status(400).json({ message: 'userId is required' });
    }
    if (!Number.isInteger(numericRating) || numericRating < 1 || numericRating > 5) {
      return res.status(400).json({ message: 'rating must be an integer from 1 to 5' });
    }

    await ensureProductReviewsTable();

    const pool = await getPool();
    const purchasedResult = await pool
      .request()
      .input('productId', sql.UniqueIdentifier, id)
      .input('userId', sql.UniqueIdentifier, normalizedUserId)
      .query(
        `SELECT TOP 1 1 AS Purchased
         FROM dbo.OrderItems oi
         INNER JOIN dbo.Orders o ON o.Id = oi.OrderId
         WHERE oi.ProductId = @productId
           AND o.UserId = @userId
           AND LOWER(o.[Status]) <> 'cancelled'`
      );

    if (purchasedResult.recordset.length === 0) {
      return res.status(403).json({ message: 'Only customers who purchased can review this product' });
    }

    const existed = await pool
      .request()
      .input('productId', sql.UniqueIdentifier, id)
      .input('userId', sql.UniqueIdentifier, normalizedUserId)
      .query(
        `SELECT TOP 1 Id
         FROM dbo.ProductReviews
         WHERE ProductId = @productId
           AND UserId = @userId`
      );

    if (existed.recordset.length > 0) {
      await pool
        .request()
        .input('id', sql.UniqueIdentifier, existed.recordset[0].Id)
        .input('rating', sql.Int, numericRating)
        .input('comment', sql.NVarChar(1000), normalizedComment)
        .query(
          `UPDATE dbo.ProductReviews
           SET Rating = @rating,
               Comment = @comment,
               UpdatedAt = SYSUTCDATETIME()
           WHERE Id = @id`
        );
    } else {
      await pool
        .request()
        .input('id', sql.UniqueIdentifier, createGuid())
        .input('productId', sql.UniqueIdentifier, id)
        .input('userId', sql.UniqueIdentifier, normalizedUserId)
        .input('rating', sql.Int, numericRating)
        .input('comment', sql.NVarChar(1000), normalizedComment)
        .query(
          `INSERT INTO dbo.ProductReviews(Id, ProductId, UserId, Rating, Comment)
           VALUES(@id, @productId, @userId, @rating, @comment)`
        );
    }

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/discounts', async (_req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      `SELECT Id, Code, [Percent], MinOrderValue, StartDate, EndDate
       FROM dbo.DiscountCodes
       WHERE IsActive = 1
       ORDER BY StartDate DESC`
    );
    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/api/discounts', async (req, res) => {
  try {
    const { id, code, percent, minOrderValue, startDate, endDate } = req.body;
    const pool = await getPool();

    await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .input('code', sql.NVarChar(40), code)
      .input('percent', sql.Decimal(5, 2), Number(percent || 0))
      .input('minOrderValue', sql.Decimal(18, 2), Number(minOrderValue || 0))
      .input('startDate', sql.DateTime2, new Date(startDate))
      .input('endDate', sql.DateTime2, new Date(endDate))
      .query(
        `INSERT INTO dbo.DiscountCodes(Id, Code, [Percent], MinOrderValue, StartDate, EndDate, IsActive)
         VALUES(@id, @code, @percent, @minOrderValue, @startDate, @endDate, 1)`
      );

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/users', async (_req, res) => {
  try {
    const pool = await getPool();
    const result = await pool.request().query(
      `SELECT Id, FullName, Email, Phone, Role, IsActive
       FROM dbo.Users
       ORDER BY CreatedAt DESC`
    );
    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/admin/revenue-by-owner', async (_req, res) => {
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
       ORDER BY Revenue DESC, OwnerName ASC`
    );

    res.json(result.recordset);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.post('/api/users', async (req, res) => {
  try {
    const { id, fullName, email, phone, role, isActive = true } = req.body;
    const pool = await getPool();

    await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .input('fullName', sql.NVarChar(120), fullName)
      .input('email', sql.NVarChar(150), email)
      .input('phone', sql.NVarChar(20), phone || null)
      .input('role', sql.NVarChar(20), role)
      .input('isActive', sql.Bit, isActive)
      .query(
        `INSERT INTO dbo.Users(Id, FullName, Email, Phone, Role, IsActive)
         VALUES(@id, @fullName, @email, @phone, @role, @isActive)`
      );

    res.status(201).json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.put('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { fullName, email, phone, role, isActive } = req.body;
    const pool = await getPool();

    await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .input('fullName', sql.NVarChar(120), fullName)
      .input('email', sql.NVarChar(150), email)
      .input('phone', sql.NVarChar(20), phone || null)
      .input('role', sql.NVarChar(20), role)
      .input('isActive', sql.Bit, isActive)
      .query(
        `UPDATE dbo.Users
         SET FullName=@fullName, Email=@email, Phone=@phone,
             Role=@role, IsActive=@isActive, UpdatedAt=SYSUTCDATETIME()
         WHERE Id=@id`
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.patch('/api/users/:id/toggle-active', async (req, res) => {
  try {
    const { id } = req.params;
    const pool = await getPool();

    await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .query(
        `UPDATE dbo.Users
         SET IsActive = CASE WHEN IsActive = 1 THEN 0 ELSE 1 END,
             UpdatedAt = SYSUTCDATETIME()
         WHERE Id = @id`
      );

    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.get('/api/orders', async (req, res) => {
  try {
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const role = String(payload?.role || '').toLowerCase();
    const isOwner = role === 'owner';
    const isCustomer = role === 'customer';
    const ownerId = isOwner ? String(payload?.sub || '') : null;
    const customerId = isCustomer ? String(payload?.sub || '') : null;

    const pool = await getPool();

    const ordersRequest = pool.request();
    if (isCustomer) {
      ordersRequest.input('customerId', sql.UniqueIdentifier, customerId);
    }

    const ordersResult = await ordersRequest.query(
      `SELECT o.Id, o.OrderCode, o.UserId, o.ShippingAddress, o.PaymentMethod,
              o.PaymentStatus, o.[Status], o.CreatedAt
       FROM dbo.Orders o
       ${isCustomer ? 'WHERE o.UserId = @customerId' : ''}
       ORDER BY o.CreatedAt DESC`
    );

    const itemsRequest = pool.request();
    if (isOwner) {
      itemsRequest.input('ownerId', sql.UniqueIdentifier, ownerId);
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
            ${isOwner ? 'WHERE p.OwnerId = @ownerId' : ''}`
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

app.post('/api/orders', async (req, res) => {
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
      .input('id', sql.UniqueIdentifier, orderId)
      .input('orderCode', sql.NVarChar(30), orderCode)
      .input('userId', sql.UniqueIdentifier, userId)
      .input('shippingAddress', sql.NVarChar(500), shippingAddress)
      .input('paymentMethod', sql.NVarChar(20), paymentMethod)
      .input('paymentStatus', sql.NVarChar(20), paymentStatus)
      .input('status', sql.NVarChar(20), status)
      .input('subtotal', sql.Decimal(18, 2), Number(subtotal || 0))
      .input('discountAmount', sql.Decimal(18, 2), Number(discountAmount || 0))
      .input('total', sql.Decimal(18, 2), Number(total || 0))
      .query(
        `INSERT INTO dbo.Orders(Id, OrderCode, UserId, ShippingAddress, PaymentMethod, PaymentStatus, [Status], Subtotal, DiscountAmount, Total)
         VALUES(@id, @orderCode, @userId, @shippingAddress, @paymentMethod, @paymentStatus, @status, @subtotal, @discountAmount, @total)`
      );

    for (const item of items || []) {
      const quantity = Number(item.quantity || 1);
      const sizeLabel = String(item.sizeLabel || '').trim().toUpperCase();
      const colorHexRaw = String(item.colorHex || '').trim().toUpperCase();
      const colorHex = colorHexRaw.length === 0
        ? null
        : (colorHexRaw.startsWith('#') ? colorHexRaw : `#${colorHexRaw}`);

      if (!item.productId || !sizeLabel || quantity <= 0) {
        throw new Error('Invalid order item payload');
      }

      const reserveReq = new sql.Request(transaction);
      reserveReq
        .input('productId', sql.UniqueIdentifier, item.productId)
        .input('sizeLabel', sql.NVarChar(10), sizeLabel)
        .input('quantity', sql.Int, quantity);

      let reserveResult;
      if (colorHex) {
        reserveReq.input('colorHex', sql.NVarChar(10), colorHex);
        reserveResult = await reserveReq.query(
          `UPDATE pv
           SET pv.Stock = pv.Stock - @quantity
           OUTPUT INSERTED.ColorHex AS ReservedColorHex
           FROM dbo.ProductVariants pv
           WHERE pv.ProductId = @productId
             AND UPPER(pv.SizeLabel) = @sizeLabel
             AND UPPER(pv.ColorHex) = @colorHex
             AND pv.Stock >= @quantity`
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
           )`
        );
      }

      if (!reserveResult.rowsAffected || reserveResult.rowsAffected[0] === 0) {
        throw new Error(`Insufficient stock for product ${item.productId}, size ${sizeLabel}`);
      }
      const reservedColorHex = reserveResult.recordset[0]?.ReservedColorHex || colorHex;

      const syncProductStockReq = new sql.Request(transaction);
      await syncProductStockReq
        .input('productId', sql.UniqueIdentifier, item.productId)
        .query(
          `UPDATE dbo.Products
           SET Stock = ISNULL((
             SELECT SUM(Stock)
             FROM dbo.ProductVariants
             WHERE ProductId = @productId
           ), 0),
           UpdatedAt = SYSUTCDATETIME()
           WHERE Id = @productId`
        );

      const itemReq = new sql.Request(transaction);
      await itemReq
        .input('orderId', sql.UniqueIdentifier, orderId)
        .input('productId', sql.UniqueIdentifier, item.productId)
        .input('sizeLabel', sql.NVarChar(10), sizeLabel)
        .input('colorHex', sql.NVarChar(10), reservedColorHex)
        .input('quantity', sql.Int, quantity)
        .input('unitPrice', sql.Decimal(18, 2), Number(item.unitPrice || 0))
        .input('lineTotal', sql.Decimal(18, 2), Number(item.lineTotal || 0))
        .query(
          `INSERT INTO dbo.OrderItems(OrderId, ProductId, SizeLabel, ColorHex, Quantity, UnitPrice, LineTotal)
           VALUES(@orderId, @productId, @sizeLabel, @colorHex, @quantity, @unitPrice, @lineTotal)`
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

app.patch('/api/orders/:id/status', async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const normalizedStatus = String(status || '').trim().toLowerCase();
    if (!['processing', 'delivered', 'cancelled'].includes(normalizedStatus)) {
      return res.status(400).json({ message: 'Invalid status' });
    }
    await ensureProductOwnerColumn();
    const payload = getTokenPayload(req);
    const isOwner = payload?.role === 'owner';
    const ownerId = isOwner ? String(payload.sub || '') : null;

    const pool = await getPool();

    if (isOwner) {
      const ownsOrder = await pool
        .request()
        .input('id', sql.UniqueIdentifier, id)
        .input('ownerId', sql.UniqueIdentifier, ownerId)
        .query(
          `SELECT TOP 1 o.Id
           FROM dbo.Orders o
           INNER JOIN dbo.OrderItems oi ON oi.OrderId = o.Id
           INNER JOIN dbo.Products p ON p.Id = oi.ProductId
           WHERE o.Id = @id AND p.OwnerId = @ownerId`
        );

      if (ownsOrder.recordset.length === 0) {
        return res.status(403).json({ message: 'Forbidden' });
      }
    }

    const currentOrderResult = await pool
      .request()
      .input('id', sql.UniqueIdentifier, id)
      .query(
        `SELECT TOP 1 Id, [Status]
         FROM dbo.Orders
         WHERE Id = @id`
      );

    if (currentOrderResult.recordset.length === 0) {
      return res.status(404).json({ message: 'Order not found' });
    }

    const previousStatus = String(currentOrderResult.recordset[0].Status || '').toLowerCase();
    const shouldRestoreStock = normalizedStatus === 'cancelled' && previousStatus !== 'cancelled';

    const transaction = new sql.Transaction(pool);
    await transaction.begin();

    try {
      await new sql.Request(transaction)
        .input('id', sql.UniqueIdentifier, id)
        .input('status', sql.NVarChar(20), normalizedStatus)
        .query(
          `UPDATE dbo.Orders
           SET [Status]=@status, UpdatedAt=SYSUTCDATETIME()
           WHERE Id=@id`
        );

      if (shouldRestoreStock) {
        const itemsResult = await new sql.Request(transaction)
          .input('orderId', sql.UniqueIdentifier, id)
          .query(
            `SELECT ProductId, SizeLabel, ColorHex, Quantity
             FROM dbo.OrderItems
             WHERE OrderId = @orderId`
          );

        const productIds = new Set();
        for (const item of itemsResult.recordset) {
          const productId = String(item.ProductId);
          const sizeLabel = String(item.SizeLabel || '').trim().toUpperCase();
          const colorHexRaw = String(item.ColorHex || '').trim().toUpperCase();
          const colorHex = colorHexRaw.length === 0
            ? null
            : (colorHexRaw.startsWith('#') ? colorHexRaw : `#${colorHexRaw}`);
          const quantity = Number(item.Quantity || 0);

          if (!productId || !sizeLabel || quantity <= 0) {
            continue;
          }

          const restockReq = new sql.Request(transaction)
            .input('productId', sql.UniqueIdentifier, productId)
            .input('sizeLabel', sql.NVarChar(10), sizeLabel)
            .input('quantity', sql.Int, quantity);

          let restockResult;
          if (colorHex) {
            restockReq.input('colorHex', sql.NVarChar(10), colorHex);
            restockResult = await restockReq.query(
              `UPDATE dbo.ProductVariants
               SET Stock = Stock + @quantity
               WHERE ProductId = @productId
                 AND UPPER(SizeLabel) = @sizeLabel
                 AND UPPER(ColorHex) = @colorHex`
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
               )`
            );
          }

          if (!restockResult.rowsAffected || restockResult.rowsAffected[0] === 0) {
            throw new Error(`Failed to restore stock for product ${productId}, size ${sizeLabel}`);
          }

          productIds.add(productId);
        }

        for (const productId of productIds) {
          await new sql.Request(transaction)
            .input('productId', sql.UniqueIdentifier, productId)
            .query(
              `UPDATE dbo.Products
               SET Stock = ISNULL((
                 SELECT SUM(Stock)
                 FROM dbo.ProductVariants
                 WHERE ProductId = @productId
               ), 0),
               UpdatedAt = SYSUTCDATETIME()
               WHERE Id = @productId`
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

app.post('/api/tryon/batch', async (req, res) => {
  try {
    const payload = getTokenPayload(req);
    if (!payload?.sub) {
      return res.status(401).json({ message: 'Unauthorized' });
    }

    const modelImage = String(req.body?.modelImage || '').trim();
    const garmentsRaw = Array.isArray(req.body?.garments) ? req.body.garments : [];
    const category = normalizeTryOnCategory(req.body?.category);
    const mode = normalizeTryOnMode(req.body?.mode);

    if (!isSupportedTryOnImage(modelImage) && !isLikelyLocalFilePath(modelImage)) {
      return res.status(400).json({
        message: 'modelImage must be a public URL, data:image/...;base64,... or local file path',
      });
    }

    if (garmentsRaw.length === 0) {
      return res.status(400).json({ message: 'garments is required' });
    }

    if (garmentsRaw.length > 12) {
      return res.status(400).json({ message: 'Maximum 12 garments per request' });
    }

    const garments = garmentsRaw
      .map((item, index) => {
        const garmentImage = String(item?.garmentImage || '').trim();
        const garmentName = String(item?.garmentName || '').trim();
        const productId = String(item?.productId || '').trim();
        return {
          index,
          garmentImage,
          garmentName,
          productId,
        };
      })
      .filter((item) => item.garmentImage.length > 0);

    if (garments.length === 0) {
      return res.status(400).json({ message: 'No valid garmentImage found in garments' });
    }

    for (const item of garments) {
      if (!isSupportedTryOnImage(item.garmentImage) && !isLikelyLocalFilePath(item.garmentImage)) {
        return res.status(400).json({
          message: `garments[${item.index}].garmentImage must be URL, base64 data:image, or local file path`,
        });
      }
    }

    const normalizedModelImage = await normalizeTryOnImageInput(modelImage);

    const results = [];
    let totalCreditsUsed = 0;

    for (const garment of garments) {
      try {
        const normalizedGarmentImage = await normalizeTryOnImageInput(
          garment.garmentImage
        );
        const prediction = await runFashnTryOn({
          modelImage: normalizedModelImage,
          garmentImage: normalizedGarmentImage,
          category,
          mode,
          outputFormat: 'jpeg',
        });

        totalCreditsUsed += Number(prediction.creditsUsed || 0);
        results.push({
          productId: garment.productId || null,
          garmentName: garment.garmentName || null,
          status: 'completed',
          predictionId: prediction.id,
          outputImage: prediction.output[0] || null,
          outputImages: prediction.output,
          creditsUsed: prediction.creditsUsed,
          error: null,
        });
      } catch (error) {
        results.push({
          productId: garment.productId || null,
          garmentName: garment.garmentName || null,
          status: 'failed',
          predictionId: null,
          outputImage: null,
          outputImages: [],
          creditsUsed: 0,
          error: error.message,
        });
      }
    }

    res.json({
      modelName: 'tryon-v1.6',
      category,
      mode,
      total: garments.length,
      successCount: results.filter((item) => item.status === 'completed').length,
      failureCount: results.filter((item) => item.status === 'failed').length,
      totalCreditsUsed,
      estimatedCostUsd: Number((totalCreditsUsed * 0.075).toFixed(4)),
      results,
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`API is running on http://localhost:${PORT}`);
});
