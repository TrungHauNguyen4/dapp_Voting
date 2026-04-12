import { Vote } from "lucide-react";
import type { Candidate } from "./contract";

interface Props {
  candidates: Candidate[];
  hasVoted: boolean;
  expired: boolean;
  connected: boolean;
  onVote: (id: number) => void;
}

export function CandidatesTable({ candidates, hasVoted, expired, connected, onVote }: Props) {
  const disabled = hasVoted || expired || !connected;

  return (
    <div className="rounded-xl border border-blue-500/20 bg-[#0d0d2b]/60 backdrop-blur-md overflow-hidden mb-8">
      <div className="p-5 border-b border-blue-500/15">
        <h2 className="text-white" style={{ fontSize: "1.1rem", fontWeight: 600 }}>
          Danh Sách Ứng Cử Viên
        </h2>
        <p className="text-gray-500 mt-1" style={{ fontSize: "0.8rem" }}>
          {candidates.length} ứng cử viên đã đăng ký
          {hasVoted && " · Bạn đã bỏ phiếu"}
          {expired && " · Đã kết thúc thời gian bầu cử"}
        </p>
      </div>

      {/* Desktop table */}
      <div className="hidden sm:block overflow-x-auto">
        <table className="w-full">
          <thead>
            <tr className="border-b border-blue-500/15 text-gray-400" style={{ fontSize: "0.75rem" }}>
              <th className="text-left px-5 py-3 tracking-wider">ID</th>
              <th className="text-left px-5 py-3 tracking-wider">ỨNG CỬ VIÊN</th>
              <th className="text-left px-5 py-3 tracking-wider">SỐ PHIẾU</th>
              <th className="text-right px-5 py-3 tracking-wider">THAO TÁC</th>
            </tr>
          </thead>
          <tbody>
            {candidates.map((c) => (
              <tr key={c.id} className="border-b border-blue-500/10 hover:bg-purple-500/5 transition-colors">
                <td className="px-5 py-4 text-purple-400 font-mono" style={{ fontSize: "0.875rem" }}>#{c.id}</td>
                <td className="px-5 py-4 text-white">{c.name}</td>
                <td className="px-5 py-4">
                  <span className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-blue-500/10 text-blue-300 font-mono" style={{ fontSize: "0.8rem" }}>
                    {c.voteCount}
                  </span>
                </td>
                <td className="px-5 py-4 text-right">
                  <button
                    onClick={() => onVote(c.id)}
                    disabled={disabled}
                    className="inline-flex items-center gap-1.5 px-4 py-2 rounded-lg text-white transition-all cursor-pointer disabled:opacity-30 disabled:cursor-not-allowed bg-gradient-to-r from-blue-600 to-purple-600 hover:from-blue-500 hover:to-purple-500 shadow-md shadow-blue-500/20"
                    style={{ fontSize: "0.8rem" }}
                  >
                    <Vote className="w-3.5 h-3.5" />
                    Bỏ phiếu
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* Mobile cards */}
      <div className="sm:hidden divide-y divide-blue-500/10">
        {candidates.map((c) => (
          <div key={c.id} className="p-4 flex items-center justify-between">
            <div>
              <div className="text-white">{c.name}</div>
              <div className="text-gray-500 font-mono" style={{ fontSize: "0.75rem" }}>
                #{c.id} · {c.voteCount} phiếu
              </div>
            </div>
            <button
              onClick={() => onVote(c.id)}
              disabled={disabled}
              className="px-3 py-1.5 rounded-lg text-white bg-gradient-to-r from-blue-600 to-purple-600 disabled:opacity-30 disabled:cursor-not-allowed cursor-pointer"
              style={{ fontSize: "0.8rem" }}
            >
              Bỏ phiếu
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}
