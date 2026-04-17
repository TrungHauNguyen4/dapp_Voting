import { ethers } from "ethers";

const REQUIRED_FUNCTIONS = ["registerVoter", "addCandidate", "vote", "startElection", "endElection"];
const LOCK_STORAGE_KEY_DEFAULT = "votingdapp.lockedContractAddress";
const LOCK_OVERRIDE_KEY_DEFAULT = "votingdapp.allowAddressOverride";
let BACKEND_BASE_URL = "";
let runtimeConfig = null;
let ACTIVE_CONTRACT_ADDRESS = "";
let ACTIVE_CONTRACT_ABI = [];

const state = {
  provider: null,
  signer: null,
  contract: null,
  account: null,
  isAdmin: false,
  isWhitelisted: false,
  hasVoted: false,
  electionActive: false,
  electionState: null,
  electionEndTs: 0,
  candidates: [],
  countdownTimer: null
};

const el = {
  connectWalletBtn: document.getElementById("connectWalletBtn"),
  walletAddress: document.getElementById("walletAddress"),
  roleBadge: document.getElementById("roleBadge"),
  electionStatus: document.getElementById("electionStatus"),
  countdown: document.getElementById("countdown"),
  checkBackendBtn: document.getElementById("checkBackendBtn"),
  syncDbBtn: document.getElementById("syncDbBtn"),
  backendStatus: document.getElementById("backendStatus"),
  globalMessage: document.getElementById("globalMessage"),
  loadingOverlay: document.getElementById("loadingOverlay"),
  loadingText: document.getElementById("loadingText"),
  adminSection: document.getElementById("adminSection"),
  voterSection: document.getElementById("voterSection"),
  whitelistForm: document.getElementById("whitelistForm"),
  whitelistInput: document.getElementById("whitelistInput"),
  candidateForm: document.getElementById("candidateForm"),
  candidateId: document.getElementById("candidateId"),
  candidateName: document.getElementById("candidateName"),
  candidateImage: document.getElementById("candidateImage"),
  candidateImageFile: document.getElementById("candidateImageFile"),
  candidateImagePreview: document.getElementById("candidateImagePreview"),
  durationInput: document.getElementById("durationInput"),
  createElectionBtn: document.getElementById("createElectionBtn"),
  startElectionBtn: document.getElementById("startElectionBtn"),
  whitelistMessage: document.getElementById("whitelistMessage"),
  candidatesContainer: document.getElementById("candidatesContainer"),
  resultsSection: document.getElementById("resultsSection"),
  resultsContainer: document.getElementById("resultsContainer")
};

function setLoading(visible, text = "Đang chờ giao dịch trên blockchain...") {
  el.loadingText.textContent = text;
  el.loadingOverlay.classList.toggle("hidden", !visible);
}

function setMessage(message, type = "info") {
  const palette = {
    info: "#e9f2ff",
    success: "#e8faf2",
    error: "#fdecec"
  };
  el.globalMessage.textContent = message;
  el.globalMessage.style.background = palette[type] || palette.info;
}

function safeErrorMessage(error) {
  if (error?.code === 4001) {
    return "Bạn đã từ chối giao dịch trên MetaMask.";
  }
  return error?.shortMessage || error?.reason || error?.message || "Giao dịch thất bại.";
}

function shortAddress(address) {
  if (!address) return "Chưa kết nối";
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

function setCandidateImagePreview(src) {
  if (!el.candidateImagePreview) return;

  if (!src) {
    el.candidateImagePreview.classList.add("hidden");
    el.candidateImagePreview.removeAttribute("src");
    return;
  }

  el.candidateImagePreview.src = src;
  el.candidateImagePreview.classList.remove("hidden");
}

function isValidImageUrl(url) {
  return /^https?:\/\//i.test(url) || /^data:image\//i.test(url);
}

function readFileAsDataUrl(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => reject(new Error("Không đọc được file ảnh."));
    reader.readAsDataURL(file);
  });
}

function loadImageElement(dataUrl) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error("File ảnh không hợp lệ."));
    img.src = dataUrl;
  });
}

async function optimizeImageFile(file) {
  if (!file.type.startsWith("image/")) {
    throw new Error("Vui lòng chọn đúng định dạng file ảnh.");
  }

  const sourceDataUrl = await readFileAsDataUrl(file);
  const img = await loadImageElement(sourceDataUrl);

  const maxSide = 640;
  const scale = Math.min(1, maxSide / Math.max(img.width, img.height));
  const width = Math.max(1, Math.round(img.width * scale));
  const height = Math.max(1, Math.round(img.height * scale));

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;

  const ctx = canvas.getContext("2d");
  if (!ctx) {
    throw new Error("Trình duyệt không hỗ trợ xử lý ảnh.");
  }

  ctx.drawImage(img, 0, 0, width, height);

  let quality = 0.85;
  let optimized = canvas.toDataURL("image/jpeg", quality);
  const maxLength = 180000;

  while (optimized.length > maxLength && quality > 0.45) {
    quality -= 0.08;
    optimized = canvas.toDataURL("image/jpeg", quality);
  }

  return optimized;
}

async function resolveCandidateImage() {
  const imageUrl = el.candidateImage.value.trim();
  const imageFile = el.candidateImageFile?.files?.[0];

  if (imageFile) {
    return optimizeImageFile(imageFile);
  }

  if (imageUrl) {
    if (!isValidImageUrl(imageUrl)) {
      throw new Error("URL ảnh không hợp lệ. Vui lòng dùng http(s) hoặc data:image.");
    }
    return imageUrl;
  }

  return "";
}

async function handleCandidateFilePreview() {
  const imageFile = el.candidateImageFile?.files?.[0];
  if (!imageFile) {
    const maybeUrl = el.candidateImage.value.trim();
    setCandidateImagePreview(isValidImageUrl(maybeUrl) ? maybeUrl : "");
    return;
  }

  try {
    const dataUrl = await readFileAsDataUrl(imageFile);
    setCandidateImagePreview(dataUrl);
  } catch {
    setCandidateImagePreview("");
  }
}

function handleCandidateUrlPreview() {
  if (el.candidateImageFile?.files?.length) {
    return;
  }
  const maybeUrl = el.candidateImage.value.trim();
  setCandidateImagePreview(isValidImageUrl(maybeUrl) ? maybeUrl : "");
}

function setBackendStatus(message, tone = "info") {
  if (!el.backendStatus) return;

  el.backendStatus.textContent = message;
  if (tone === "error") {
    el.backendStatus.style.color = "#b42318";
  } else if (tone === "success") {
    el.backendStatus.style.color = "#036666";
  } else {
    el.backendStatus.style.color = "#5a6b8f";
  }
}

async function checkBackendHealth() {
  try {
    const response = await fetch(`${BACKEND_BASE_URL}/api/health`);
    const payload = await response.json();
    if (!response.ok || !payload?.ok) {
      throw new Error(payload?.message || "API backend chưa sẵn sàng");
    }
    setBackendStatus("API backend: đang hoạt động", "success");
    return true;
  } catch (error) {
    setBackendStatus("API backend: không kết nối được", "error");
    setMessage(`Khong goi duoc backend: ${safeErrorMessage(error)}`, "error");
    return false;
  }
}

async function syncToDatabase() {
  const healthy = await checkBackendHealth();
  if (!healthy) return;

  try {
    setLoading(true, "Đang đồng bộ dữ liệu vào SQL Server...");
    const response = await fetch(`${BACKEND_BASE_URL}/api/sync`, {
      method: "POST"
    });
    const payload = await response.json();

    if (!response.ok || !payload?.ok) {
      throw new Error(payload?.message || "Đồng bộ dữ liệu thất bại");
    }

    const syncedBlock = payload?.data?.toBlock ?? "?";
    setBackendStatus(`Đồng bộ thành công tới block ${syncedBlock}`, "success");
    setMessage("Đã đồng bộ dữ liệu blockchain vào SQL Server.", "success");
  } catch (error) {
    setBackendStatus("Đồng bộ CSDL thất bại", "error");
    setMessage(safeErrorMessage(error), "error");
  } finally {
    setLoading(false);
  }
}

function normalizeChainId(chainId) {
  if (typeof chainId === "number") {
    return `0x${chainId.toString(16)}`.toLowerCase();
  }
  if (typeof chainId === "string" && chainId.startsWith("0x")) {
    return chainId.toLowerCase();
  }
  const parsed = Number(chainId);
  if (!Number.isNaN(parsed)) {
    return `0x${parsed.toString(16)}`.toLowerCase();
  }
  return "";
}

function hasFunction(iface, name) {
  return iface.fragments.some((fragment) => fragment.type === "function" && fragment.name === name);
}

function normalizeBaseUrl(url) {
  if (!url) return "";
  return url.replace(/\/+$/, "");
}

function resolveBackendBaseUrl(cfg) {
  const configured = normalizeBaseUrl(cfg?.backend?.baseUrl || "");
  if (configured) {
    return configured;
  }

  const host = window.location.hostname;
  if (host === "localhost" || host === "127.0.0.1") {
    return "http://localhost:4000";
  }

  // Empty value means same-origin requests, e.g. /api/health
  return "";
}

function enforceSingleContract(address, lockConfig = {}) {
  if (lockConfig.enabled === false) return;

  const storageKey = lockConfig.storageKey || LOCK_STORAGE_KEY_DEFAULT;
  const overrideKey = lockConfig.overrideKey || LOCK_OVERRIDE_KEY_DEFAULT;
  const locked = localStorage.getItem(storageKey);
  const allowOverride = localStorage.getItem(overrideKey) === "true";
  const previousAddresses = Array.isArray(lockConfig.previousAddresses)
    ? lockConfig.previousAddresses.map((item) => String(item).toLowerCase())
    : [];

  if (!locked) {
    localStorage.setItem(storageKey, address);
    return;
  }

  if (locked.toLowerCase() === address.toLowerCase()) {
    return;
  }

  // Allow safe migration from known old contract addresses after a planned upgrade.
  if (previousAddresses.includes(locked.toLowerCase())) {
    localStorage.setItem(storageKey, address);
    return;
  }

  if (!allowOverride) {
    throw new Error(`Hệ thống đang khóa tại contract ${locked}. Để đổi contract, bật cờ override rồi tải lại trang.`);
  }

  localStorage.setItem(storageKey, address);
  localStorage.removeItem(overrideKey);
}

async function loadRuntimeConfig() {
  if (runtimeConfig) return runtimeConfig;

  const response = await fetch("/contract-config.json", { cache: "no-store" });
  if (!response.ok) {
    throw new Error("Không đọc được file contract-config.json.");
  }

  const cfg = await response.json();
  const address = cfg?.contract?.address?.trim();
  const abi = cfg?.contract?.abi;

  if (!address || !ethers.isAddress(address)) {
    throw new Error("contract-config.json thiếu địa chỉ contract hợp lệ.");
  }

  if (!Array.isArray(abi) || abi.length === 0) {
    throw new Error("contract-config.json thiếu ABI. Hãy dán ABI từ Remix.");
  }

  const iface = new ethers.Interface(abi);
  const missing = REQUIRED_FUNCTIONS.filter((fn) => !hasFunction(iface, fn));
  if (missing.length > 0) {
    throw new Error(`ABI thiếu hàm bắt buộc: ${missing.join(", ")}`);
  }

  enforceSingleContract(address, cfg?.lock || {});

  ACTIVE_CONTRACT_ADDRESS = address;
  ACTIVE_CONTRACT_ABI = abi;
  runtimeConfig = {
    network: {
      chainId: cfg?.network?.chainId || "0xaa36a7",
      chainName: cfg?.network?.chainName || "Sepolia Testnet",
      rpcUrl: cfg?.network?.rpcUrl || "",
      blockExplorerUrl: cfg?.network?.blockExplorerUrl || ""
    },
    backend: {
      baseUrl: cfg?.backend?.baseUrl || ""
    },
    lock: cfg?.lock || {}
  };

  BACKEND_BASE_URL = resolveBackendBaseUrl(cfg);

  return runtimeConfig;
}

async function ensureCorrectNetwork(provider) {
  const targetChainId = normalizeChainId(runtimeConfig?.network?.chainId || "0xaa36a7");
  const currentChainId = normalizeChainId(await provider.send("eth_chainId", []));

  if (currentChainId === targetChainId) return;

  try {
    await window.ethereum.request({
      method: "wallet_switchEthereumChain",
      params: [{ chainId: targetChainId }]
    });
  } catch (error) {
    if (error?.code === 4902 && runtimeConfig?.network?.rpcUrl) {
      await window.ethereum.request({
        method: "wallet_addEthereumChain",
        params: [{
          chainId: targetChainId,
          chainName: runtimeConfig.network.chainName,
          rpcUrls: [runtimeConfig.network.rpcUrl],
          blockExplorerUrls: runtimeConfig.network.blockExplorerUrl ? [runtimeConfig.network.blockExplorerUrl] : undefined
        }]
      });
      return;
    }
    throw new Error(`Sai mạng. Hãy chuyển MetaMask sang ${runtimeConfig.network.chainName}.`);
  }
}

async function verifyContractExists(provider) {
  const code = await provider.getCode(ACTIVE_CONTRACT_ADDRESS);
  if (!code || code === "0x") {
    throw new Error(`Không tìm thấy contract tại địa chỉ ${ACTIVE_CONTRACT_ADDRESS}.`);
  }
}

function updateStatus() {
  el.walletAddress.textContent = shortAddress(state.account);
  el.roleBadge.textContent = state.account ? (state.isAdmin ? "Quản trị" : "Cử tri") : "Khách";
  if (state.electionState === "CREATED") {
    el.electionStatus.textContent = "Đã tạo / Chưa bắt đầu";
  } else if (state.electionState === "VOTING") {
    el.electionStatus.textContent = "Đang diễn ra";
  } else if (state.electionState === "ENDED") {
    el.electionStatus.textContent = "Đã kết thúc";
  } else {
    el.electionStatus.textContent = state.electionActive ? "Đang diễn ra" : "Đã kết thúc / Chưa bắt đầu";
  }
  el.adminSection.classList.toggle("hidden", !state.isAdmin);

  const showVotingList = state.account && state.isWhitelisted;
  el.whitelistMessage.classList.toggle("hidden", showVotingList);
  if (!showVotingList && state.account) {
    el.whitelistMessage.textContent = "Ví của bạn không nằm trong whitelist. Vui lòng liên hệ Admin.";
  }

  const showResults = state.electionState ? state.electionState === "ENDED" : !state.electionActive;
  el.resultsSection.classList.toggle("hidden", !showResults);
}

async function connectWallet() {
  if (!window.ethereum) {
    setMessage("Không tìm thấy MetaMask. Vui lòng cài đặt extension trước.", "error");
    return;
  }

  try {
    setLoading(true, "Đang kết nối ví...");
    await loadRuntimeConfig();
    const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
    state.account = accounts[0];
    state.provider = new ethers.BrowserProvider(window.ethereum);
    await ensureCorrectNetwork(state.provider);
    state.signer = await state.provider.getSigner();
    await verifyContractExists(state.provider);
    state.contract = new ethers.Contract(ACTIVE_CONTRACT_ADDRESS, ACTIVE_CONTRACT_ABI, state.signer);

    window.ethereum.removeAllListeners?.("accountsChanged");
    window.ethereum.on("accountsChanged", () => {
      window.location.reload();
    });

    await refreshAll();
    setMessage("Kết nối ví thành công.", "success");
  } catch (error) {
    setMessage(safeErrorMessage(error), "error");
  } finally {
    setLoading(false);
  }
}

async function refreshAll() {
  if (!state.contract || !state.account) return;

  state.isAdmin = await checkIsAdmin();
  state.hasVoted = await checkHasVoted();
  state.isWhitelisted = await checkWhitelist();
  await loadElectionState();
  await loadCandidates();
  await renderResults();
  updateStatus();
  renderCandidates();
  runCountdown();
}

async function checkIsAdmin() {
  try {
    if (state.contract.admin) {
      const admin = await state.contract.admin();
      return admin.toLowerCase() === state.account.toLowerCase();
    }

    if (state.contract.owner) {
      const owner = await state.contract.owner();
      return owner.toLowerCase() === state.account.toLowerCase();
    }

    return false;
  } catch {
    return false;
  }
}

async function checkHasVoted() {
  try {
    if (state.contract.hasVoted) {
      return await state.contract.hasVoted(state.account);
    }
  } catch {
    // fallback below
  }

  try {
    if (state.contract.voters) {
      return await state.contract.voters(state.account);
    }
  } catch {
    return false;
  }

  return false;
}

async function checkWhitelist() {
  try {
    if (state.isAdmin) return true;
    if (state.contract.isRegistered) {
      return await state.contract.isRegistered(state.account);
    }
  } catch {
    // fallback below
  }

  try {
    if (state.isAdmin) return true;
    if (state.contract.isWhitelisted) {
      return await state.contract.isWhitelisted(state.account);
    }
  } catch {
    // fallback below
  }

  try {
    if (state.isAdmin) return true;
    if (state.contract.whitelist) {
      return await state.contract.whitelist(state.account);
    }
  } catch {
    // fallback below
  }

  return false;
}

async function loadElectionState() {
  state.electionState = null;

  try {
    if (state.contract.electionState) {
      const rawState = Number(await state.contract.electionState());
      if (rawState === 0) state.electionState = "CREATED";
      if (rawState === 1) state.electionState = "VOTING";
      if (rawState === 2) state.electionState = "ENDED";
    }
  } catch {
    state.electionState = null;
  }

  try {
    if (state.contract.electionActive) {
      state.electionActive = await state.contract.electionActive();
    } else if (state.electionState) {
      state.electionActive = state.electionState === "VOTING";
    }
  } catch {
    state.electionActive = state.electionState ? state.electionState === "VOTING" : false;
  }

  try {
    if (state.contract.electionEndTime) {
      const end = await state.contract.electionEndTime();
      state.electionEndTs = Number(end);
    } else if (state.contract.endTime) {
      const end = await state.contract.endTime();
      state.electionEndTs = Number(end);
    }
  } catch {
    state.electionEndTs = 0;
  }
}

async function loadCandidates() {
  const fallbackImage = "https://images.unsplash.com/photo-1522556189639-b150d5e287e8?auto=format&fit=crop&w=900&q=80";
  state.candidates = [];

  try {
    const count = Number(await state.contract.candidatesCount());
    for (let i = 1; i <= count; i += 1) {
      const c = await state.contract.candidates(i);
      state.candidates.push({
        id: Number(c.id ?? i),
        name: c.name || `Ứng cử viên ${i}`,
        image: c.image || fallbackImage,
        voteCount: Number(c.voteCount ?? 0)
      });
    }
  } catch {
    state.candidates = [];
  }
}

function renderCandidates() {
  el.candidatesContainer.innerHTML = "";

  if (!state.account) {
    el.candidatesContainer.innerHTML = "<p>Vui lòng kết nối ví để xem danh sách ứng cử viên.</p>";
    return;
  }

  if (!state.isWhitelisted) {
    return;
  }

  if (!state.candidates.length) {
    el.candidatesContainer.innerHTML = "<p>Chưa có ứng cử viên nào.</p>";
    return;
  }

  for (const candidate of state.candidates) {
    const card = document.createElement("article");
    card.className = "card";

    const disabled = state.hasVoted || !state.electionActive;
    card.innerHTML = `
      <img src="${candidate.image}" alt="${candidate.name}" onerror="this.src='https://placehold.co/640x360?text=Candidate'" />
      <div class="card-body">
        <p><strong>ID:</strong> ${candidate.id}</p>
        <p><strong>Tên:</strong> ${candidate.name}</p>
        <p><strong>Số phiếu:</strong> ${candidate.voteCount}</p>
        <button class="btn btn-primary vote-btn" data-candidate-id="${candidate.id}" ${disabled ? "disabled" : ""}>
          ${state.hasVoted ? "Đã bỏ phiếu" : "Bỏ phiếu"}
        </button>
      </div>
    `;

    el.candidatesContainer.appendChild(card);
  }
}

async function renderResults() {
  el.resultsContainer.innerHTML = "";

  if (state.electionActive) {
    return;
  }

  const results = await getResults();
  if (!results.length) {
    el.resultsContainer.innerHTML = "<p>Chưa có kết quả để hiển thị.</p>";
    return;
  }

  const sorted = [...results].sort((a, b) => b.voteCount - a.voteCount);
  const topVotes = sorted[0]?.voteCount ?? 0;

  for (const row of sorted) {
    const item = document.createElement("div");
    const isWinner = topVotes > 0 && row.voteCount === topVotes;
    item.className = `result-item${isWinner ? " winner" : ""}`;
    item.innerHTML = `<span>${row.name} (ID ${row.id})${isWinner ? '<span class="winner-tag">Thắng cử</span>' : ""}</span><strong>${row.voteCount} phiếu</strong>`;
    el.resultsContainer.appendChild(item);
  }
}

async function refreshAfterCountdownEnded() {
  if (state.contract?.finalizeElectionIfEnded) {
    try {
      const tx = await state.contract.finalizeElectionIfEnded();
      await tx.wait();
    } catch {
      // Read-only fallback is acceptable if finalization tx is not sent.
    }
  }

  await loadElectionState();
  await loadCandidates();
  updateStatus();
  renderCandidates();
  await renderResults();
}

function runCountdown() {
  if (state.countdownTimer) {
    clearInterval(state.countdownTimer);
  }

  if (!state.electionEndTs) {
    el.countdown.textContent = "--:--";
    return;
  }

  state.countdownTimer = setInterval(() => {
    const now = Math.floor(Date.now() / 1000);
    const left = state.electionEndTs - now;

    if (left <= 0) {
      el.countdown.textContent = "00:00";
      state.electionActive = false;
      clearInterval(state.countdownTimer);
      refreshAfterCountdownEnded().catch(() => {
        updateStatus();
        renderCandidates();
        renderResults();
      });
      return;
    }

    const mins = String(Math.floor(left / 60)).padStart(2, "0");
    const secs = String(left % 60).padStart(2, "0");
    el.countdown.textContent = `${mins}:${secs}`;
  }, 1000);
}

// ===== Contract interaction stubs required by specification =====
async function registerVoter(voterAddress) {
  const tx = await state.contract.registerVoter(voterAddress);
  await tx.wait();
}

async function addCandidate(name, image) {
  const hasImageOverload = state.contract.interface.fragments.some(
    (fragment) => fragment.type === "function" && fragment.name === "addCandidate" && fragment.inputs?.length === 2
  );

  const tx = hasImageOverload
    ? await state.contract["addCandidate(string,string)"](name, image)
    : await state.contract["addCandidate(string)"](name);

  await tx.wait();
}

async function vote(candidateId) {
  const tx = await state.contract.vote(candidateId);
  await tx.wait();
}

async function getResults() {
  try {
    const rows = await state.contract.getResults();
    return rows.map((r) => ({
      id: Number(r.id),
      name: r.name,
      image: r.image || "",
      voteCount: Number(r.voteCount)
    }));
  } catch {
    return state.candidates
      .map((c) => ({ id: c.id, name: c.name, image: c.image, voteCount: c.voteCount }))
      .sort((a, b) => b.voteCount - a.voteCount);
  }
}

async function handleWhitelistSubmit(event) {
  event.preventDefault();
  if (!state.contract) return;

  const addresses = el.whitelistInput.value
    .split(/\s|,|;|\n/g)
    .map((s) => s.trim())
    .filter(Boolean);

  if (!addresses.length) {
    setMessage("Vui lòng nhập ít nhất 1 địa chỉ hợp lệ.", "error");
    return;
  }

  try {
    setLoading(true, "Đang nạp whitelist...");
    for (const address of addresses) {
      if (!ethers.isAddress(address)) {
        throw new Error(`Địa chỉ không hợp lệ: ${address}`);
      }
      await registerVoter(address);
    }
    setMessage("Nạp whitelist thành công.", "success");
    el.whitelistForm.reset();
  } catch (error) {
    setMessage(safeErrorMessage(error), "error");
  } finally {
    setLoading(false);
  }
}

async function handleCandidateSubmit(event) {
  event.preventDefault();
  if (!state.contract) return;

  if (state.electionState && state.electionState !== "CREATED") {
    setMessage("Không thể thêm ứng cử viên sau khi bầu cử đã bắt đầu.", "error");
    return;
  }

  const id = Number(el.candidateId.value);
  const name = el.candidateName.value.trim();
  let image = "";

  if (!id || !name) {
    setMessage("Vui lòng điền ID và tên ứng cử viên.", "error");
    return;
  }

  try {
    image = await resolveCandidateImage();
    if (!image) {
      throw new Error("Vui lòng nhập URL ảnh hoặc chọn file ảnh.");
    }

    setLoading(true, "Đang thêm ứng cử viên...");
    await addCandidate(name, image);
    await loadCandidates();
    renderCandidates();
    setMessage("Thêm ứng cử viên thành công.", "success");
    el.candidateForm.reset();
    setCandidateImagePreview("");
  } catch (error) {
    setMessage(safeErrorMessage(error), "error");
  } finally {
    setLoading(false);
  }
}

async function handleVote(candidateId) {
  if (!state.contract || !state.account) return;

  try {
    setLoading(true, "Đang gửi giao dịch bỏ phiếu...");
    await vote(candidateId);
    state.hasVoted = true;
    await loadCandidates();
    renderCandidates();
    setMessage("Bỏ phiếu thành công.", "success");
  } catch (error) {
    setMessage(safeErrorMessage(error), "error");
  } finally {
    setLoading(false);
  }
}

async function handleStartElection() {
  if (!state.contract) return;

  const minutes = Number(el.durationInput.value) || 5;
  const durationSeconds = minutes * 60;

  try {
    setLoading(true, "Đang bắt đầu bầu cử...");
    if (!state.contract.startElection) {
      throw new Error("Contract không có hàm startElection.");
    }

    const tx = await state.contract.startElection(durationSeconds);
    await tx.wait();

    await loadElectionState();
    updateStatus();
    runCountdown();
    setMessage("Đã bắt đầu bầu cử.", "success");
  } catch (error) {
    setMessage(safeErrorMessage(error), "error");
  } finally {
    setLoading(false);
  }
}

async function handleCreateElection() {
  if (!state.contract) return;

  if (state.electionState && state.electionState !== "ENDED") {
    setMessage("Chỉ tạo kỳ bầu cử mới sau khi kỳ hiện tại đã kết thúc.", "error");
    return;
  }

  try {
    setLoading(true, "Đang tạo kỳ bầu cử mới...");

    if (!state.contract.createElection) {
      throw new Error("Contract không có hàm createElection.");
    }

    const tx = await state.contract.createElection();
    await tx.wait();

    await refreshAll();
    setMessage("Đã tạo kỳ bầu cử mới. Bạn có thể nạp whitelist và thêm ứng cử viên.", "success");
  } catch (error) {
    setMessage(safeErrorMessage(error), "error");
  } finally {
    setLoading(false);
  }
}

function bindEvents() {
  el.connectWalletBtn.addEventListener("click", connectWallet);
  el.checkBackendBtn.addEventListener("click", checkBackendHealth);
  el.syncDbBtn.addEventListener("click", syncToDatabase);
  el.whitelistForm.addEventListener("submit", handleWhitelistSubmit);
  el.candidateForm.addEventListener("submit", handleCandidateSubmit);
  el.candidateImage.addEventListener("input", handleCandidateUrlPreview);
  el.candidateImageFile?.addEventListener("change", handleCandidateFilePreview);
  el.createElectionBtn?.addEventListener("click", handleCreateElection);
  el.startElectionBtn.addEventListener("click", handleStartElection);

  el.candidatesContainer.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) return;

    const voteBtn = target.closest(".vote-btn");
    if (!voteBtn) return;

    const id = Number(voteBtn.dataset.candidateId);
    if (!id) return;
    handleVote(id);
  });
}

bindEvents();
updateStatus();
setMessage("Nhấn 'Kết nối ví MetaMask' để bắt đầu. Dự án sẽ dùng đúng 1 địa chỉ contract đã khóa.");
