// Add window.ethereum type for TypeScript
declare global {
  interface Window {
    ethereum?: any;
  }
}
// ===============================
// SMART CONTRACT CONFIGURATION
// ===============================
export const contractAddress = "0x8C600354f69F1A8284b176ab3065668e39C9A95D";
export const contractABI = [
  {
    "inputs": [
      { "internalType": "string", "name": "_name", "type": "string" }
    ],
    "name": "addCandidate",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  { "inputs": [], "stateMutability": "nonpayable", "type": "constructor" },
  {
    "inputs": [
      { "internalType": "uint256", "name": "_candidateId", "type": "uint256" }
    ],
    "name": "vote",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "anonymous": false,
    "inputs": [
      { "indexed": true, "internalType": "uint256", "name": "_candidateId", "type": "uint256" }
    ],
    "name": "votedEvent",
    "type": "event"
  },
  {
    "inputs": [
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "name": "candidates",
    "outputs": [
      { "internalType": "uint256", "name": "id", "type": "uint256" },
      { "internalType": "string", "name": "name", "type": "string" },
      { "internalType": "uint256", "name": "voteCount", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "candidatesCount",
    "outputs": [
      { "internalType": "uint256", "name": "", "type": "uint256" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      { "internalType": "address", "name": "", "type": "address" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      { "internalType": "address", "name": "", "type": "address" }
    ],
    "name": "voters",
    "outputs": [
      { "internalType": "bool", "name": "", "type": "bool" }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "winningCandidate",
    "outputs": [
      { "internalType": "string", "name": "_winnerName", "type": "string" }
    ],
    "stateMutability": "view",
    "type": "function"
  }
];

export interface Candidate {
  id: number;
  name: string;
  voteCount: number;
}

import { ethers } from "ethers";

// Kết nối contract
export async function getContract() {
  if (!window.ethereum) throw new Error("MetaMask not found");
  const provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  const signer = await provider.getSigner();
  return new ethers.Contract(contractAddress, contractABI, signer);
}

// Lấy số lượng ứng viên
export async function fetchCandidates(): Promise<Candidate[]> {
  const contract = await getContract();
  const count = await contract.candidatesCount();
  const candidates: Candidate[] = [];
  for (let i = 1; i <= Number(count); i++) {
    const c = await contract.candidates(i);
    candidates.push({ id: Number(c.id), name: c.name, voteCount: Number(c.voteCount) });
  }
  return candidates;
}

// Kiểm tra đã vote chưa
export async function hasVoted(address: string): Promise<boolean> {
  const contract = await getContract();
  return await contract.voters(address);
}

// Kiểm tra owner
export async function isOwner(address: string): Promise<boolean> {
  const contract = await getContract();
  const owner = await contract.owner();
  return owner.toLowerCase() === address.toLowerCase();
}

// Vote cho ứng viên
export async function vote(candidateId: number): Promise<void> {
  const contract = await getContract();
  await contract.vote(candidateId);
}

// Thêm ứng viên
export async function addCandidate(name: string): Promise<void> {
  const contract = await getContract();
  await contract.addCandidate(name);
}

// Lấy winner
export async function getWinner(): Promise<string> {
  const contract = await getContract();
  return await contract.winningCandidate();
}
