import { useState, useCallback, useEffect } from "react";
import { Toaster, toast } from "sonner";
import { Header } from "./components/Header";
import { AdminSection } from "./components/AdminSection";
import { CandidatesTable } from "./components/CandidatesTable";
import { WinnerCard } from "./components/WinnerCard";
import {
  fetchCandidates,
  hasVoted as checkHasVoted,
  isOwner as checkIsOwner,
  vote as voteCandidate,
  addCandidate as addCandidateOnChain,
  getWinner as fetchWinner,
  type Candidate
} from "./components/contract";

export default function App() {
  const [walletAddress, setWalletAddress] = useState<string | null>(null);
  const [isOwner, setIsOwner] = useState(false);
  const [hasVoted, setHasVoted] = useState(false);
  const [candidates, setCandidates] = useState<Candidate[]>([]);
  const [winner, setWinner] = useState({ name: "—", voteCount: 0 });
  const [expired, setExpired] = useState(false);


  // Fetch candidates from blockchain
  const renderCandidates = useCallback(async () => {
    try {
      const result = await fetchCandidates();
      setCandidates(result);
    } catch (e) {
      setCandidates([]);
    }
  }, []);

  // Fetch winner from blockchain
  const getWinner = useCallback(async () => {
    try {
      const winnerName = await fetchWinner();
      setWinner({ name: winnerName, voteCount: 0 }); // voteCount không có trong contract
    } catch (e) {
      setWinner({ name: "—", voteCount: 0 });
    }
  }, []);


  useEffect(() => {
    renderCandidates();
    getWinner();
    // Không có votingEnd trên contract, có thể bỏ expired hoặc lấy từ contract nếu có
  }, [renderCandidates, getWinner]);

  const connectWallet = async () => {
    if (!window.ethereum) {
      toast.error("Không tìm thấy MetaMask");
      return;
    }
    toast.promise(
      (async () => {
        const accounts = await window.ethereum.request({ method: "eth_requestAccounts" });
        const addr = accounts[0];
        setWalletAddress(addr);
        const owner = await checkIsOwner(addr);
        setIsOwner(owner);
        const voted = await checkHasVoted(addr);
        setHasVoted(voted);
        return addr;
      })(),
      {
        loading: "Đang kết nối ví...",
        success: (addr: string) => `Đã kết nối: ${addr.slice(0, 6)}...${addr.slice(-4)}`,
        error: "Kết nối thất bại",
      }
    );
  };

  const handleVote = async (candidateId: number) => {
    if (!walletAddress) {
      toast.error("Vui lòng kết nối ví trước");
      return;
    }
    toast.promise(
      (async () => {
        await voteCandidate(candidateId);
        setHasVoted(true);
        await renderCandidates();
        await getWinner();
      })(),
      {
        loading: "Đang gửi giao dịch...",
        success: () => "Bỏ phiếu thành công!",
        error: "Giao dịch thất bại",
      }
    );
  };

  const handleAddCandidate = async (name: string) => {
    toast.promise(
      (async () => {
        await addCandidateOnChain(name);
        await renderCandidates();
        await getWinner();
      })(),
      {
        loading: "Đang thêm ứng cử viên...",
        success: () => `Đã thêm ứng cử viên "${name}"!`,
        error: "Thêm ứng cử viên thất bại",
      }
    );
  };

  return (
    <div className="min-h-screen bg-[#060614] text-white">
      {/* Background glow effects */}
      <div className="fixed inset-0 pointer-events-none overflow-hidden">
        <div className="absolute top-[-20%] left-[-10%] w-[500px] h-[500px] rounded-full bg-purple-700/10 blur-[120px]" />
        <div className="absolute bottom-[-20%] right-[-10%] w-[500px] h-[500px] rounded-full bg-blue-700/10 blur-[120px]" />
      </div>

      <div className="relative z-10">
        <Header walletAddress={walletAddress} onConnect={connectWallet} votingEnd={null} />

        <main className="max-w-5xl mx-auto px-4 sm:px-6 py-8">
          {isOwner && <AdminSection onAddCandidate={handleAddCandidate} />}

          <WinnerCard name={winner.name} voteCount={winner.voteCount} />

          <CandidatesTable
            candidates={candidates}
            hasVoted={hasVoted}
            expired={expired}
            connected={!!walletAddress}
            onVote={handleVote}
          />

          {!walletAddress && (
            <div className="text-center py-8 text-gray-500" style={{ fontSize: "0.875rem" }}>
              Kết nối ví để tham gia bầu cử
            </div>
          )}
        </main>
      </div>

      <Toaster
        position="bottom-right"
        theme="dark"
        toastOptions={{
          style: {
            background: "#1a1a3e",
            border: "1px solid rgba(139, 92, 246, 0.2)",
            color: "#e2e8f0",
          },
        }}
      />
    </div>
  );
}
