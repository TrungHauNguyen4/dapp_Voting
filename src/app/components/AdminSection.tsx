import { useState } from "react";
import { Plus, ShieldCheck } from "lucide-react";

interface AdminSectionProps {
  onAddCandidate: (name: string) => void;
}

export function AdminSection({ onAddCandidate }: AdminSectionProps) {
  const [name, setName] = useState("");

  const handleAdd = () => {
    if (!name.trim()) return;
    onAddCandidate(name.trim());
    setName("");
  };

  return (
    <div className="rounded-xl border border-purple-500/30 bg-[#0d0d2b]/60 backdrop-blur-md p-6 mb-8">
      <div className="flex items-center gap-2 mb-4">
        <ShieldCheck className="w-5 h-5 text-yellow-400" />
        <h2 className="text-yellow-300" style={{ fontSize: "1.1rem", fontWeight: 600 }}>Bảng Điều Khiển Admin</h2>
      </div>
      <div className="flex gap-3">
        <input
          type="text"
          value={name}
          onChange={(e) => setName(e.target.value)}
          onKeyDown={(e) => e.key === "Enter" && handleAdd()}
          placeholder="Nhập tên ứng cử viên..."
          className="flex-1 px-4 py-2.5 rounded-lg bg-[#1a1a3e]/80 border border-purple-500/20 text-white placeholder-gray-500 focus:outline-none focus:border-purple-400 transition-colors"
        />
        <button
          onClick={handleAdd}
          className="flex items-center gap-2 px-5 py-2.5 rounded-lg bg-gradient-to-r from-yellow-500 to-orange-500 hover:from-yellow-400 hover:to-orange-400 text-black cursor-pointer transition-all"
          style={{ fontWeight: 600 }}
        >
          <Plus className="w-4 h-4" />
          Thêm ứng cử viên
        </button>
      </div>
    </div>
  );
}
