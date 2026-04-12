import { Trophy, Crown } from "lucide-react";

interface Props {
  name: string;
  voteCount: number;
}

export function WinnerCard({ name, voteCount }: Props) {
  return (
    <div className="relative rounded-xl p-[2px] bg-gradient-to-r from-yellow-400 via-amber-500 to-yellow-600 mb-8">
      <div className="rounded-xl bg-[#0d0d2b] p-6">
        <div className="flex items-center gap-2 mb-3">
          <Crown className="w-5 h-5 text-yellow-400" />
          <span className="text-yellow-300 tracking-wider" style={{ fontSize: "0.75rem", fontWeight: 600 }}>
            ỨNG CỬ VIÊN DẪN ĐẦU
          </span>
        </div>
        <div className="flex items-center justify-between">
          <div>
            <h3 className="text-white" style={{ fontSize: "1.5rem", fontWeight: 700 }}>{name}</h3>
            <p className="text-gray-400 mt-1">Đang dẫn đầu cuộc bầu cử</p>
          </div>
          <div className="flex items-center gap-3">
            <div className="text-right">
              <div className="text-yellow-400 font-mono" style={{ fontSize: "2rem", fontWeight: 700 }}>{voteCount}</div>
              <div className="text-gray-500" style={{ fontSize: "0.75rem" }}>tổng số phiếu</div>
            </div>
            <Trophy className="w-10 h-10 text-yellow-500/40" />
          </div>
        </div>
      </div>
    </div>
  );
}
