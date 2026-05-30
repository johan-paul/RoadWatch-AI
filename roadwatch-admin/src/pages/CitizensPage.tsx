import { useEffect, useState } from 'react'
import { RefreshCw, Ban, CheckCircle, Search, Users } from 'lucide-react'
import { listUsers, reinstateUser } from '../api/services'
import { SuspendModal } from '../components/SuspendModal'
import { Pagination } from '../components/ui/Pagination'
import type { User } from '../api/types'

const PAGE_SIZE = 30

export function CitizensPage() {
  const [users, setUsers]               = useState<User[]>([])
  const [loading, setLoading]           = useState(true)
  const [page, setPage]                 = useState(1)
  const [search, setSearch]             = useState('')
  const [suspendTarget, setSuspendTarget] = useState<User | null>(null)
  const [actioning, setActioning]       = useState<string | null>(null)

  const load = () => {
    setLoading(true)
    listUsers('citizen', page, PAGE_SIZE).then(setUsers).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [page])

  const handleReinstate = async (u: User) => {
    setActioning(u.id)
    try {
      await reinstateUser(u.id)
      load()
    } finally {
      setActioning(null)
    }
  }

  const filtered = search.trim()
    ? users.filter(
        (u) =>
          u.name.toLowerCase().includes(search.toLowerCase()) ||
          u.phone_number.includes(search),
      )
    : users

  return (
    <div>
      {/* ── Sticky header ───────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Citizens</h1>
            <p className="page-sub">Registered citizen accounts</p>
          </div>
          <button onClick={load} className="btn-secondary">
            <RefreshCw size={14} />
            Refresh
          </button>
        </div>
      </div>

      <div className="p-8">
        {/* ── Search toolbar ──────────────────────────────────────────────── */}
        <div className="toolbar mb-6">
          <Search size={14} className="shrink-0 text-slate-400" />
          <input
            className="flex-1 bg-transparent text-sm text-slate-900 placeholder-slate-400 outline-none"
            placeholder="Search by name or phone number…"
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>

        {/* ── Table ───────────────────────────────────────────────────────── */}
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr>
                  <th className="table-th">Name</th>
                  <th className="table-th">Phone</th>
                  <th className="table-th">Trust Score</th>
                  <th className="table-th">Status</th>
                  <th className="table-th">Joined</th>
                  <th className="table-th">Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={6} className="py-16 text-center">
                      <div className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-indigo-600 border-t-transparent" />
                    </td>
                  </tr>
                ) : filtered.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-20 text-center">
                      <div className="flex flex-col items-center gap-3">
                        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-100">
                          <Users size={22} className="text-slate-400" />
                        </div>
                        <p className="text-sm font-medium text-slate-500">No citizens found</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  filtered.map((u) => (
                    <tr key={u.id} className="table-tr">
                      {/* Name */}
                      <td className="table-td">
                        <div className="flex items-center gap-3">
                          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-blue-500 to-indigo-600 text-[11px] font-bold text-white shadow-sm shadow-blue-200">
                            {u.name[0].toUpperCase()}
                          </div>
                          <span className="font-medium text-slate-900">{u.name}</span>
                        </div>
                      </td>
                      {/* Phone */}
                      <td className="table-td text-slate-500">{u.phone_number}</td>
                      {/* Trust Score */}
                      <td className="table-td">
                        <div className="flex items-center gap-2.5">
                          <div className="h-1.5 w-20 overflow-hidden rounded-full bg-slate-100">
                            <div
                              className={`h-1.5 rounded-full transition-all ${
                                u.trust_score >= 70 ? 'bg-emerald-500' :
                                u.trust_score >= 40 ? 'bg-amber-500' : 'bg-red-500'
                              }`}
                              style={{ width: `${u.trust_score}%` }}
                            />
                          </div>
                          <span className="text-xs font-medium text-slate-600">{u.trust_score}</span>
                        </div>
                      </td>
                      {/* Status */}
                      <td className="table-td">
                        <div>
                          <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold ring-1 ring-inset ${
                            u.is_suspended
                              ? 'bg-red-50 text-red-700 ring-red-200/60'
                              : 'bg-emerald-50 text-emerald-700 ring-emerald-200/60'
                          }`}>
                            {u.is_suspended ? 'Suspended' : 'Active'}
                          </span>
                          {u.is_suspended && u.suspension_reason && (
                            <p className="mt-1 max-w-[160px] truncate text-[11px] text-slate-400">
                              {u.suspension_reason}
                            </p>
                          )}
                        </div>
                      </td>
                      {/* Joined */}
                      <td className="table-td text-xs text-slate-400">
                        {new Date(u.created_at).toLocaleDateString()}
                      </td>
                      {/* Actions */}
                      <td className="table-td">
                        {u.is_suspended ? (
                          <button
                            onClick={() => handleReinstate(u)}
                            disabled={actioning === u.id}
                            className="inline-flex items-center gap-1.5 rounded-lg bg-emerald-50 px-3 py-1.5 text-xs font-medium text-emerald-700 transition hover:bg-emerald-100 disabled:opacity-40"
                          >
                            <CheckCircle size={12} />
                            Reinstate
                          </button>
                        ) : (
                          <button
                            onClick={() => setSuspendTarget(u)}
                            className="inline-flex items-center gap-1.5 rounded-lg bg-red-50 px-3 py-1.5 text-xs font-medium text-red-700 transition hover:bg-red-100"
                          >
                            <Ban size={12} />
                            Suspend
                          </button>
                        )}
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <Pagination
            page={page}
            pageSize={PAGE_SIZE}
            total={users.length + (page - 1) * PAGE_SIZE}
            onPage={setPage}
          />
        </div>
      </div>

      {suspendTarget && (
        <SuspendModal
          userId={suspendTarget.id}
          userName={suspendTarget.name}
          onClose={() => setSuspendTarget(null)}
          onDone={() => { setSuspendTarget(null); load() }}
        />
      )}
    </div>
  )
}
