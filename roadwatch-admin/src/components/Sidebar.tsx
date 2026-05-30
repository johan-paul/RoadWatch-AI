import { NavLink } from 'react-router-dom'
import {
  LayoutDashboard, MessageSquareWarning, ShieldCheck,
  Users, ClipboardList, Map, LogOut, Construction,
  Flame, IndianRupee,
} from 'lucide-react'
import { useAuth } from '../contexts/AuthContext'

const nav = [
  { to: '/',           icon: LayoutDashboard,     label: 'Dashboard' },
  { to: '/complaints', icon: MessageSquareWarning, label: 'Complaints' },
  { to: '/priority',   icon: Flame,               label: 'Priority Queue' },
  { to: '/officers',   icon: ShieldCheck,          label: 'Officers' },
  { to: '/citizens',   icon: Users,                label: 'Citizens' },
  { to: '/budget',     icon: IndianRupee,          label: 'Budget' },
  { to: '/audit',      icon: ClipboardList,        label: 'Audit Logs' },
  { to: '/map',        icon: Map,                  label: 'Map' },
]

export function Sidebar() {
  const { user, logout } = useAuth()

  return (
    <aside className="relative flex h-screen w-64 shrink-0 flex-col overflow-hidden border-r border-slate-800 bg-[#0d1424]">
      {/* Ambient glow */}
      <div className="pointer-events-none absolute -top-32 -left-16 h-72 w-72 rounded-full bg-indigo-600/10 blur-3xl" />
      <div className="pointer-events-none absolute bottom-0 right-0 h-48 w-48 rounded-full bg-violet-600/8 blur-3xl" />

      {/* ── Logo ─────────────────────────────────────────────────────────── */}
      <div className="relative flex items-center gap-3 border-b border-slate-800 px-5 py-5">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600 shadow-lg shadow-indigo-500/30">
          <Construction size={17} className="text-white" />
        </div>
        <div>
          <p className="text-sm font-bold tracking-tight text-white">RoadWatch AI</p>
          <p className="text-[10px] uppercase tracking-widest text-slate-500">Admin Panel</p>
        </div>
      </div>

      {/* ── Navigation ───────────────────────────────────────────────────── */}
      <nav className="relative flex-1 space-y-0.5 overflow-y-auto px-3 py-5">
        {nav.map(({ to, icon: Icon, label }) => (
          <NavLink
            key={to}
            to={to}
            end={to === '/'}
            className={({ isActive }) =>
              `group flex items-center gap-3 rounded-xl px-3.5 py-2.5 text-sm font-medium transition-all ${
                isActive
                  ? 'bg-indigo-500/15 text-indigo-300 ring-1 ring-inset ring-indigo-500/20'
                  : 'text-slate-400 hover:bg-slate-800/80 hover:text-slate-200'
              }`
            }
          >
            <Icon size={17} />
            {label}
          </NavLink>
        ))}
      </nav>

      {/* ── User footer ──────────────────────────────────────────────────── */}
      <div className="relative border-t border-slate-800 px-4 py-4">
        <div className="mb-2 flex items-center gap-3 px-1 py-1">
          {/* Avatar with gradient */}
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-violet-600 text-[12px] font-bold text-white shadow-md shadow-indigo-500/30">
            {user?.name?.[0]?.toUpperCase() ?? 'A'}
          </div>
          <div className="min-w-0">
            <p className="truncate text-xs font-semibold text-slate-200">
              {user?.name ?? 'Administrator'}
            </p>
            <p className="text-[10px] text-slate-500">Administrator</p>
          </div>
        </div>
        <button
          onClick={logout}
          className="flex w-full items-center gap-2.5 rounded-xl px-3 py-2 text-xs font-medium text-slate-400 transition-all hover:bg-slate-800/80 hover:text-slate-200"
        >
          <LogOut size={14} />
          Sign out
        </button>
      </div>
    </aside>
  )
}
