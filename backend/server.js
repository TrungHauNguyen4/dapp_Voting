import express from "express";
import cors from "cors";
import { getDbPool, getElectionSummaries } from "./db.js";
import { readServerConfig } from "./config.js";
import { syncOnce } from "./sync.js";

const app = express();
const cfg = readServerConfig();

app.use(cors({
  origin: cfg.corsOrigins
}));
app.use(express.json());

app.get("/api/health", async (req, res) => {
  try {
    await getDbPool(cfg.sql);
    res.json({ ok: true, message: "API va SQL Server dang hoat dong" });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.get("/api/elections", async (req, res) => {
  try {
    const pool = await getDbPool(cfg.sql);
    const rows = await getElectionSummaries(pool);
    res.json({ ok: true, data: rows });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.post("/api/sync", async (req, res) => {
  try {
    const result = await syncOnce();
    res.json({ ok: true, data: result });
  } catch (error) {
    res.status(500).json({ ok: false, message: error.message });
  }
});

app.listen(cfg.port, cfg.host, () => {
  console.log(`Voting backend dang chay tai http://${cfg.host}:${cfg.port}`);
});
