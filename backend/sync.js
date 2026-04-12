import { ethers } from "ethers";
import {
  getDbPool,
  getSyncState,
  insertEventLog,
  replaceCandidates,
  upsertElection,
  upsertSyncState,
  upsertVote,
  upsertWhitelist
} from "./db.js";
import { readContractConfig, readServerConfig } from "./config.js";

function parseChainId(chainId) {
  if (typeof chainId === "number") return chainId;
  if (typeof chainId === "string" && chainId.startsWith("0x")) return Number.parseInt(chainId, 16);
  return Number(chainId);
}

function mapElectionState(raw) {
  if (raw === 0) return "Created";
  if (raw === 1) return "Voting";
  if (raw === 2) return "Ended";
  return "Created";
}

async function fetchCandidates(contract) {
  const count = Number(await contract.candidatesCount());
  const candidates = [];

  for (let i = 1; i <= count; i += 1) {
    const c = await contract.candidates(i);
    candidates.push({
      id: Number(c.id ?? i),
      name: c.name || `Candidate ${i}`,
      image: c.image || "",
      voteCount: Number(c.voteCount ?? 0)
    });
  }

  return candidates;
}

async function queryLogsInBatches(contract, filter, fromBlock, toBlock, step = 45000) {
  const all = [];

  if (fromBlock > toBlock) {
    return all;
  }

  let start = fromBlock;
  while (start <= toBlock) {
    const end = Math.min(start + step - 1, toBlock);
    const rows = await contract.queryFilter(filter, start, end);
    all.push(...rows);
    start = end + 1;
  }

  return all;
}

async function safeQueryFilter(contract, filter, fromBlock, toBlock) {
  let step = 12000;

  while (true) {
    try {
      return await queryLogsInBatches(contract, filter, fromBlock, toBlock, step);
    } catch (error) {
      const message = String(error?.message || "").toLowerCase();
      const isTimeout = message.includes("timed out") || message.includes("timeout") || message.includes("maximum block range");

      if (!isTimeout || step <= 500) {
        throw error;
      }

      step = Math.max(500, Math.floor(step / 2));
      console.warn(`RPC timeout, giam kich thuoc batch con ${step} blocks...`);
    }
  }
}

export async function syncOnce() {
  const appCfg = readContractConfig();
  const serverCfg = readServerConfig();
  const chainId = parseChainId(appCfg.network.chainId);

  const provider = new ethers.JsonRpcProvider(appCfg.network.rpcUrl);
  const contract = new ethers.Contract(appCfg.contract.address, appCfg.contract.abi, provider);
  const latestBlock = await provider.getBlockNumber();
  const toBlock = Math.max(0, latestBlock - serverCfg.confirmations);

  const adminAddress = await contract.admin();
  const rawState = Number(await contract.electionState());
  const electionState = mapElectionState(rawState);
  const endTime = Number(await contract.endTime());
  const startTimeUtc = null;
  const endTimeUtc = endTime > 0 ? new Date(endTime * 1000) : null;

  const pool = await getDbPool(serverCfg.sql);
  const electionId = await upsertElection(pool, {
    contractAddress: appCfg.contract.address,
    chainId,
    adminAddress,
    state: electionState,
    startTimeUtc,
    endTimeUtc
  });

  const candidates = await fetchCandidates(contract);
  await replaceCandidates(pool, electionId, candidates);

  const fromBlockStored = await getSyncState(pool, chainId, appCfg.contract.address);
  const configuredStartBlock = Number(appCfg?.sync?.startBlock ?? Math.max(0, toBlock - 120000));
  const fromBlock = fromBlockStored == null ? configuredStartBlock : fromBlockStored + 1;

  if (fromBlock <= toBlock) {
    const voterRegisteredFilter = contract.filters.VoterRegistered();
    const voteCastFilter = contract.filters.VoteCast();

    const registeredEvents = await safeQueryFilter(contract, voterRegisteredFilter, fromBlock, toBlock);
    const voteEvents = await safeQueryFilter(contract, voteCastFilter, fromBlock, toBlock);

    for (const ev of registeredEvents) {
      const walletAddress = ev.args?.voter;
      await upsertWhitelist(pool, {
        electionId,
        walletAddress,
        registeredBy: adminAddress
      });

      await insertEventLog(pool, {
        electionId,
        contractAddress: appCfg.contract.address,
        chainId,
        eventName: "VoterRegistered",
        transactionHash: ev.transactionHash,
        blockNumber: Number(ev.blockNumber),
        logIndex: Number(ev.index ?? 0),
        payload: {
          voter: walletAddress
        }
      });
    }

    for (const ev of voteEvents) {
      const voterAddress = ev.args?.voter;
      const candidateId = Number(ev.args?.candidateId);

      await upsertVote(pool, {
        electionId,
        voterAddress,
        candidateId,
        transactionHash: ev.transactionHash,
        blockNumber: Number(ev.blockNumber)
      });

      await insertEventLog(pool, {
        electionId,
        contractAddress: appCfg.contract.address,
        chainId,
        eventName: "VoteCast",
        transactionHash: ev.transactionHash,
        blockNumber: Number(ev.blockNumber),
        logIndex: Number(ev.index ?? 0),
        payload: {
          voter: voterAddress,
          candidateId
        }
      });
    }
  }

  await upsertSyncState(pool, chainId, appCfg.contract.address, toBlock);

  return {
    electionId,
    chainId,
    contractAddress: appCfg.contract.address,
    electionState,
    candidates: candidates.length,
    fromBlock,
    toBlock,
    latestBlock
  };
}
