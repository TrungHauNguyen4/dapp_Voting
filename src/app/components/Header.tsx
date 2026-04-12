import { useState, useEffect } from "react";
import { Wallet, Timer, Zap } from "lucide-react";


interface HeaderProps {
  walletAddress: string | null;
  onConnect: () => void;
  votingEnd: number | null;
}

export function Header({ walletAddress, onConnect, votingEnd }: HeaderProps) {
  const [timeLeft, setTimeLeft] = useState("");

  useEffect(() => {
    if (typeof votingEnd !== "number") {
      setTimeLeft("");
      return;
    }
    const tick = () => {
      const diff = votingEnd - Date.now();
      if (diff <= 0) {
        setTimeLeft("Đã kết thúc bầu cử");
        return;
      }
      const h = Math.floor(diff / 3600000);
      const m = Math.floor((diff % 3600000) / 60000);
      const s = Math.floor((diff % 60000) / 1000);
      setTimeLeft(`${h.toString().padStart(2, "0")}:${m.toString().padStart(2, "0")}:${s.toString().padStart(2, "0")}`);
    };
    tick();
    const id = setInterval(tick, 1000);
    return () => clearInterval(id);
  }, [votingEnd]);

  const truncated = walletAddress
    ? `${walletAddress.slice(0, 6)}...${walletAddress.slice(-4)}`
    : null;

  return (
    <header className="sticky top-0 z-50 backdrop-blur-xl bg-[#0a0a1a]/70 border-b border-purple-500/20">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-4 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Zap className="w-6 h-6 text-purple-400" />
          <span className="text-white tracking-wider" style={{ fontSize: "1.25rem", fontWeight: 700 }}>
            Bầu Cử <span className="text-transparent bg-clip-text bg-gradient-to-r from-blue-400 to-purple-500">DApp</span>
          </span>
        </div>

        <div className="flex items-center gap-3 sm:gap-6">
          <div className="flex items-center gap-2 px-3 py-1.5 rounded-lg bg-purple-500/10 border border-purple-500/20">
            <Timer className="w-4 h-4 text-purple-400" />
            <span className="text-purple-300 font-mono" style={{ fontSize: "0.875rem" }}>
              {timeLeft}
            </span>
          </div>

          <button
            onClick={onConnect}
            className="flex items-center gap-2 px-4 py-2 rounded-lg cursor-pointer transition-all duration-300 bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 text-white shadow-lg shadow-purple-500/25"
          >
            <Wallet className="w-4 h-4" />
            <span style={{ fontSize: "0.875rem" }}>
              {truncated || "Kết nối ví"}
            </span>
          </button>
        </div>
      </div>
    </header>
  );
}
