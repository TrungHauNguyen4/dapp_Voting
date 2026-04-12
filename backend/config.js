import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { fileURLToPath } from "url";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");
const contractConfigPath = path.join(projectRoot, "contract-config.json");

export function readContractConfig() {
  if (!fs.existsSync(contractConfigPath)) {
    throw new Error("Khong tim thay contract-config.json");
  }

  const raw = fs.readFileSync(contractConfigPath, "utf8");
  const cfg = JSON.parse(raw);

  if (!cfg?.contract?.address || cfg.contract.address === "0x0000000000000000000000000000000000000000") {
    throw new Error("contract.address chua duoc cap nhat trong contract-config.json");
  }

  if (!Array.isArray(cfg?.contract?.abi) || cfg.contract.abi.length === 0) {
    throw new Error("contract.abi chua duoc cap nhat trong contract-config.json");
  }

  if (!cfg?.network?.rpcUrl || cfg.network.rpcUrl.includes("YOUR_KEY")) {
    throw new Error("network.rpcUrl chua hop le trong contract-config.json");
  }

  return cfg;
}

export function readServerConfig() {
  const useWindowsAuth = String(process.env.SQL_USE_WINDOWS_AUTH || "true").toLowerCase() === "true";
  const rawCorsOrigins = String(process.env.CORS_ORIGINS || "*").trim();
  const rawServer = process.env.SQL_SERVER || "MSI\\MSSQLSERVER01";
  const normalizedServer = rawServer.replace(/\\{2,}/g, "\\");

  let corsOrigins = "*";
  if (rawCorsOrigins !== "*") {
    corsOrigins = rawCorsOrigins
      .split(",")
      .map((origin) => origin.trim())
      .filter(Boolean);
  }

  const sqlConfig = {
    server: normalizedServer,
    database: process.env.SQL_DATABASE || "VotingDApp",
    options: {
      encrypt: String(process.env.SQL_ENCRYPT || "false").toLowerCase() === "true",
      trustServerCertificate: String(process.env.SQL_TRUST_CERT || "true").toLowerCase() === "true"
    },
    pool: {
      max: 10,
      min: 0,
      idleTimeoutMillis: 30000
    }
  };

  if (useWindowsAuth) {
    sqlConfig.driver = "msnodesqlv8";
    sqlConfig.options.trustedConnection = true;
    sqlConfig.connectionString = `Driver={ODBC Driver 17 for SQL Server};Server=${sqlConfig.server};Database=${sqlConfig.database};Trusted_Connection=Yes;Integrated Security=SSPI;`;
  }

  if (!useWindowsAuth) {
    if (!process.env.SQL_USER || !process.env.SQL_PASSWORD) {
      throw new Error("Thieu SQL_USER hoac SQL_PASSWORD trong file .env");
    }

    sqlConfig.user = process.env.SQL_USER;
    sqlConfig.password = process.env.SQL_PASSWORD;

    if (normalizedServer.includes("\\")) {
      const parts = normalizedServer.split("\\").filter(Boolean);
      if (parts.length >= 2) {
        const host = parts[0];
        const instanceName = parts[1];
        sqlConfig.server = host;
        sqlConfig.options.instanceName = instanceName;
      }
    }
  }

  return {
    host: process.env.HOST || "0.0.0.0",
    port: Number(process.env.PORT || 4000),
    corsOrigins,
    sql: sqlConfig,
    confirmations: Number(process.env.SYNC_CONFIRMATIONS || 3)
  };
}
