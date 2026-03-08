const sql = require("mssql");

const config = {
  server: process.env.DB_SERVER || "localhost",
  port: Number(process.env.DB_PORT || 1433),
  database: process.env.DB_NAME || "ClothingStoreDB",
  user: process.env.DB_USER || "sa",
  password: process.env.DB_PASSWORD || "",
  options: {
    encrypt: String(process.env.DB_ENCRYPT || "false") === "true",
    trustServerCertificate:
      String(process.env.DB_TRUST_SERVER_CERT || "true") === "true",
  },
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

let poolPromise;

function getPool() {
  if (!poolPromise) {
    poolPromise = sql.connect(config);
  }
  return poolPromise;
}

/**
 * Create OTP table if it doesn't exist
 */
async function ensureOtpTable() {
  try {
    const pool = await getPool();
    await pool.request().query(
      `IF OBJECT_ID('dbo.UserOTP', 'U') IS NULL
       BEGIN
         CREATE TABLE dbo.UserOTP (
           Id UNIQUEIDENTIFIER NOT NULL CONSTRAINT PK_UserOTP PRIMARY KEY DEFAULT NEWID(),
           UserId UNIQUEIDENTIFIER NOT NULL,
           Email NVARCHAR(150) NOT NULL,
           OTPCode NVARCHAR(10) NOT NULL,
           Attempts INT NOT NULL DEFAULT 0,
           MaxAttempts INT NOT NULL DEFAULT 3,
           IsVerified BIT NOT NULL DEFAULT 0,
           IsExpired BIT NOT NULL DEFAULT 0,
           CreatedAt DATETIME2(0) NOT NULL DEFAULT SYSUTCDATETIME(),
           ExpiresAt DATETIME2(0) NOT NULL,
           VerifiedAt DATETIME2(0) NULL,
           CONSTRAINT FK_UserOTP_Users FOREIGN KEY (UserId) REFERENCES dbo.Users(Id)
         );
         CREATE INDEX IX_UserOTP_UserId ON dbo.UserOTP(UserId);
         CREATE INDEX IX_UserOTP_Email ON dbo.UserOTP(Email);
         CREATE INDEX IX_UserOTP_Code ON dbo.UserOTP(OTPCode);
       END`,
    );
    console.log("✅ UserOTP table ensured");
  } catch (error) {
    console.error("❌ Error ensuring OTP table:", error.message);
  }
}

module.exports = { sql, getPool, ensureOtpTable };
