import { useEffect, useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { RefreshCw, Flame, ArrowUpRight } from 'lucide-react'
import { getPriorityQueue, escalateComplaint } from '../api/services'
import { Badge, severityVariant, statusVariant, statusLabel } from '../components/ui/Badge'

export function PriorityPage() {
  const navigate = useNavigate()
  const [queue, setQueue]       = useState<any[]>([])
  const [loading, setLoading]   = useState(true)
  const [escalating, setEscalating] = useState<string | null>(null)

  const load = () => {
    setLoading(true)
    getPriorityQueue(50).then(setQueue).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleEscalate = async (id: string) => {
    if (!confirm('Escalate this complaint? The assigned officer will receive an emergency alert.')) return
    setEscalating(id)
    try {
      await escalateComplaint(id)
      load()
    } catch (e: any) {
      alert(e.response?.data?.detail ?? 'Failed to escalate.')
    } finally {
      setEscalating(null)
    }
  }

  function scoreColor(score: number) {
    if (score >= 4) return 'text-red-600 bg-red-50 ring-red-200/60'
    if (score >= 2) return 'text-amber-600 bg-amber-50 ring-amber-200/60'
    return 'text-emerald-600 bg-emerald-50 ring-emerald-200/60'
  }

  function scoreLabel(score: number) {
    if (score >= 4) return 'Critical'
    if (score >= 2) return 'High'
    return 'Normal'
  }

  return (
    <div>
      {/* ── Sticky header ─────────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Priority Queue</h1>
            <p className="page-sub">Open complaints ranked by urgency — severity × risk × density × age</p>
          </div>
          <button onClick={load} className="btn-secondary">
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </div>

      <div className="p-8">
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr>
                  <th className="table-th">Rank</th>
                  <th className="table-th">Priority</th>
                  <th className="table-th">Damage Type</th>
                  <th className="table-th">Severity</th>
                  <th className="table-th">Status</th>
                  <th className="table-th">Score</th>
                  <th className="table-th">Location</th>
                  <th className="table-th">Reported</th>
                  <th className="table-th">Actions</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={9} className="py-16 text-center">
                      <div className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-indigo-600 border-t-transparent" />
                    </td>
                  </tr>
                ) : queue.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="py-16 text-center text-sm text-slate-400">
                      No open complaints.
                    </td>
                  </tr>
                ) : (
                  queue.map((item, idx) => (
                    <tr
                      key={item.complaint_id}
                      className="table-tr cursor-pointer"
                      onClick={() => navigate(`/complaints/${item.complaint_id}`)}
                    >
                      {/* Rank */}
                      <td className="table-td">
                        <span className={`inline-flex h-6 w-6 items-center justify-center rounded-full text-xs font-bold ${
                          idx === 0 ? 'bg-red-100 text-red-700' :
                          idx <= 2  ? 'bg-amber-100 text-amber-700' :
                                      'bg-slate-100 text-slate-600'
                        }`}>
                          {idx + 1}
                        </span>
                      </td>
                      {/* Priority label */}
                      <td className="table-td">
                        <span className={`inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-[11px] font-semibold ring-1 ring-inset ${scoreColor(item.priority_score)}`}>
                          {item.priority_score >= 4 && <Flame size={10} />}
                          {scoreLabel(item.priority_score)}
                        </span>
                      </td>
                      {/* Damage type */}
                      <td className="table-td capitalize">
                        {item.damage_type?.replace('_', ' ') ?? '—'}
                      </td>
                      {/* Severity */}
                      <td className="table-td">
                        {item.severity
                          ? <Badge label={item.severity} variant={severityVariant(item.severity)} />
                          : <span className="text-slate-300">—</span>}
                      </td>
                      {/* Status */}
                      <td className="table-td">
                        <Badge label={statusLabel(item.status)} variant={statusVariant(item.status)} />
                      </td>
                      {/* Score */}
                      <td className="table-td">
                        <span className="font-mono text-xs font-semibold text-slate-700">
                          {item.priority_score.toFixed(2)}
                        </span>
                      </td>
                      {/* Location */}
                      <td className="table-td max-w-[180px] truncate text-xs text-slate-500">
                        {item.location_address ?? `${item.location_lat?.toFixed(4)}, ${item.location_lng?.toFixed(4)}`}
                      </td>
                      {/* Date */}
                      <td className="table-td text-xs text-slate-400">
                        {new Date(item.created_at).toLocaleDateString()}
                      </td>
                      {/* Actions */}
                      <td className="table-td" onClick={(e) => e.stopPropagation()}>
                        <div className="flex gap-1.5">
                          <button
                            onClick={() => handleEscalate(item.complaint_id)}
                            disabled={escalating === item.complaint_id}
                            className="inline-flex items-center gap-1 rounded-lg bg-red-50 px-2.5 py-1.5 text-[11px] font-semibold text-red-700 transition hover:bg-red-100 disabled:opacity-40"
                          >
                            <Flame size={11} />
                            Escalate
                          </button>
                          <button
                            onClick={() => navigate(`/complaints/${item.complaint_id}`)}
                            className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 transition hover:bg-indigo-50 hover:text-indigo-600"
                          >
                            <ArrowUpRight size={13} />
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        {queue.length > 0 && (
          <p className="mt-4 text-center text-[11px] text-slate-400">
            Priority Score = severity × AI risk × complaint density × recency factor
          </p>
        )}
      </div>
    </div>
  )
}
