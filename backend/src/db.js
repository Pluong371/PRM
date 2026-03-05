const sql = require('mssql');

const config = {
  server: process.env.DB_SERVER || 'localhost',
  port: Number(process.env.DB_PORT || 1433),
  database: process.env.DB_NAME || 'ClothingStoreDB',
  user: process.env.DB_USER || 'sa',
  password: process.env.DB_PASSWORD || '',
  options: {
    encrypt: String(process.env.DB_ENCRYPT || 'false') === 'true',
    trustServerCertificate:
      String(process.env.DB_TRUST_SERVER_CERT || 'true') === 'true',
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

module.exports = { sql, getPool };
