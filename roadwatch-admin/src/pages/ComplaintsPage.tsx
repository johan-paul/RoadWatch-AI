import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { RefreshCw, Filter, ArrowUpRight } from 'lucide-react'
import { listComplaints } from '../api/services'
import { Badge, statusVariant, severityVariant, statusLabel } from '../components/ui/Badge'
import { Pagination } from '../components/ui/Pagination'
import type { Complaint, ComplaintStatus, SeverityLevel } from '../api/types'

const PAGE_SIZE = 20

export function ComplaintsPage() {
  const navigate = useNavigate()
  const [complaints, setComplaints]       = useState<Complaint[]>([])
  const [loading, setLoading]             = useState(true)
  const [page, setPage]                   = useState(1)
  const [total, setTotal]                 = useState(0)
  const [statusFilter, setStatusFilter]   = useState<ComplaintStatus | ''>('')
  const [severityFilter, setSeverityFilter] = useState<SeverityLevel | ''>('')

  const load = (p = page) => {
    setLoading(true)
    listComplaints(
      statusFilter as ComplaintStatus || undefined,
      severityFilter as SeverityLevel || undefined,
      p,
      PAGE_SIZE,
    )
      .then((data) => { setComplaints(data); setTotal(data.length + (p - 1) * PAGE_SIZE) })
      .finally(() => setLoading(false))
  }

  useEffect(() => { setPage(1); load(1) }, [statusFilter, severityFilter])
  useEffect(() => { load() }, [page])

  return (
    <div>
      {/* ── Sticky header ───────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Complaints</h1>
            <p className="page-sub">All citizen-reported road issues</p>
          </div>
          <button onClick={() => load()} className="btn-secondary">
            <RefreshCw size={14} />
            Refresh
          </button>
        </div>
      </div>

      <div className="p-8">
        {/* ── Filters toolbar ─────────────────────────────────────────────── */}
        <div className="toolbar mb-6">
          <div className="flex items-center gap-2 text-slate-400">
            <Filter size={14} />
            <span className="text-xs font-semibold text-slate-500">Filter</span>
          </div>
          <div className="h-4 w-px bg-slate-200" />
          <select
            className="input w-auto text-xs"
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as ComplaintStatus | '')}
          >
            <option value="">All Statuses</option>
            {(['pending', 'assigned', 'in_progress', 'resolved', 'rejected', 'duplicate'] as ComplaintStatus[]).map(
              (s) => <option key={s} value={s}>{statusLabel(s)}</option>,
            )}
          </select>
          <select
            className="input w-auto text-xs"
            value={severityFilter}
            onChange={(e) => setSeverityFilter(e.target.value as SeverityLevel | '')}
          >
            <option value="">All Severities</option>
            <option value="high">High</option>
            <option value="medium">Medium</option>
            <option value="low">Low</option>
          </select>
        </div>

        {/* ── Table ───────────────────────────────────────────────────────── */}
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr>
                  <th className="table-th">ID</th>
                  <th className="table-th">Address</th>
                  <th className="table-th">Type</th>
                  <th className="table-th">Severity</th>
                  <th className="table-th">Status</th>
                  <th className="table-th">AI Score</th>
                  <th className="table-th">Reported</th>
                  <th className="table-th" />
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={8} className="py-16 text-center">
                      <div className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-indigo-600 border-t-transparent" />
                    </td>
                  </tr>
                ) : complaints.length === 0 ? (
                  <tr>
                    <td colSpan={8} className="py-16 text-center text-sm text-slate-400">
                      No complaints found.
                    </td>
                  </tr>
                ) : (
                  complaints.map((c) => (
                    <tr
                      key={c.id}
                      className="table-tr cursor-pointer"
                      onClick={() => navigate(`/complaints/${c.id}`)}
                    >
                      <td className="table-td font-mono text-xs text-slate-400">
                        {c.id.slice(0, 8)}…
                      </td>
                      <td className="table-td max-w-[200px] truncate text-slate-700">
                        {c.location_address ?? `${c.location_lat.toFixed(4)}, ${c.location_lng.toFixed(4)}`}
                      </td>
                      <td className="table-td capitalize text-slate-700">
                        {c.damage_type?.replace(/_/g, ' ') ?? '—'}
                      </td>
                      <td className="table-td">
                        {c.severity
                          ? <Badge label={c.severity} variant={severityVariant(c.severity)} />
                          : <span className="text-slate-300">—</span>}
                      </td>
                      <td className="table-td">
                        <Badge label={statusLabel(c.status)} variant={statusVariant(c.status)} />
                      </td>
                      <td className="table-td">
                        {c.ai_confidence_score != null ? (
                          <div className="flex items-center gap-2">
                            <div className="h-1 w-12 overflow-hidden rounded-full bg-slate-100">
                              <div
                                className={`h-1 rounded-full ${
                                  c.ai_confidence_score >= 0.70 ? 'bg-emerald-500' :
                                  c.ai_confidence_score >= 0.45 ? 'bg-amber-500' : 'bg-red-500'
                                }`}
                                style={{ width: `${c.ai_confidence_score * 100}%` }}
                              />
                            </div>
                            <span className={`text-xs font-semibold ${
                              c.ai_confidence_score >= 0.70 ? 'text-emerald-600' :
                              c.ai_confidence_score >= 0.45 ? 'text-amber-600' : 'text-red-600'
                            }`}>
                              {(c.ai_confidence_score * 100).toFixed(0)}%
                            </span>
                          </div>
                        ) : <span className="text-slate-300">—</span>}
                      </td>
                      <td className="table-td text-xs text-slate-400">
                        {new Date(c.created_at).toLocaleDateString()}
                      </td>
                      <td className="table-td">
                        <ArrowUpRight size={14} className="text-slate-300 group-hover:text-indigo-500" />
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
          <Pagination page={page} pageSize={PAGE_SIZE} total={total} onPage={(p) => setPage(p)} />
        </div>
      </div>
    </div>
  )
}
