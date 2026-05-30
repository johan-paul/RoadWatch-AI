import { useEffect, useState } from 'react'
import { RefreshCw, Filter, ClipboardList } from 'lucide-react'
import { listAuditLogs } from '../api/services'
import { Pagination } from '../components/ui/Pagination'
import type { AuditLog } from '../api/types'

const PAGE_SIZE = 50

const ACTION_STYLES: Record<string, string> = {
  login:               'bg-blue-50 text-blue-700 ring-blue-200/60',
  logout:              'bg-slate-100 text-slate-600 ring-slate-200/60',
  admin_web_login:     'bg-indigo-50 text-indigo-700 ring-indigo-200/60',
  officer_created:     'bg-emerald-50 text-emerald-700 ring-emerald-200/60',
  officer_updated:     'bg-amber-50 text-amber-700 ring-amber-200/60',
  officer_deleted:     'bg-red-50 text-red-700 ring-red-200/60',
  user_suspended:      'bg-red-50 text-red-700 ring-red-200/60',
  user_reinstated:     'bg-emerald-50 text-emerald-700 ring-emerald-200/60',
  complaint_reassigned:'bg-violet-50 text-violet-700 ring-violet-200/60',
  citizen_registered:  'bg-teal-50 text-teal-700 ring-teal-200/60',
}

const ACTION_OPTIONS = [
  'login', 'logout', 'admin_web_login',
  'officer_created', 'officer_updated', 'officer_deleted',
  'user_suspended', 'user_reinstated',
  'complaint_reassigned', 'citizen_registered',
]

export function AuditLogsPage() {
  const [logs, setLogs]               = useState<AuditLog[]>([])
  const [loading, setLoading]         = useState(true)
  const [page, setPage]               = useState(1)
  const [actionFilter, setActionFilter] = useState('')

  const load = (p = page) => {
    setLoading(true)
    listAuditLogs(p, PAGE_SIZE, actionFilter || undefined)
      .then(setLogs)
      .finally(() => setLoading(false))
  }

  useEffect(() => { setPage(1); load(1) }, [actionFilter])
  useEffect(() => { load() }, [page])

  return (
    <div>
      {/* ── Sticky header ───────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Audit Logs</h1>
            <p className="page-sub">All admin and system actions</p>
          </div>
          <button onClick={() => load()} className="btn-secondary">
            <RefreshCw size={14} />
            Refresh
          </button>
        </div>
      </div>

      <div className="p-8">
        {/* ── Filter toolbar ──────────────────────────────────────────────── */}
        <div className="toolbar mb-6">
          <div className="flex items-center gap-2 text-slate-400">
            <Filter size={14} />
            <span className="text-xs font-semibold text-slate-500">Action</span>
          </div>
          <div className="h-4 w-px bg-slate-200" />
          <select
            className="input w-auto text-xs"
            value={actionFilter}
            onChange={(e) => setActionFilter(e.target.value)}
          >
            <option value="">All Actions</option>
            {ACTION_OPTIONS.map((a) => (
              <option key={a} value={a}>{a.replace(/_/g, ' ')}</option>
            ))}
          </select>
        </div>

        {/* ── Table ───────────────────────────────────────────────────────── */}
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr>
                  <th className="table-th">Time</th>
                  <th className="table-th">Action</th>
                  <th className="table-th">Actor</th>
                  <th className="table-th">Target</th>
                  <th className="table-th">IP</th>
                  <th className="table-th">Details</th>
                </tr>
              </thead>
              <tbody>
                {loading ? (
                  <tr>
                    <td colSpan={6} className="py-16 text-center">
                      <div className="inline-block h-6 w-6 animate-spin rounded-full border-2 border-indigo-600 border-t-transparent" />
                    </td>
                  </tr>
                ) : logs.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="py-20 text-center">
                      <div className="flex flex-col items-center gap-3">
                        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-slate-100">
                          <ClipboardList size={22} className="text-slate-400" />
                        </div>
                        <p className="text-sm font-medium text-slate-500">No logs found</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  logs.map((log) => (
                    <tr key={log.id} className="table-tr">
                      {/* Time */}
                      <td className="table-td whitespace-nowrap text-xs text-slate-400">
                        {new Date(log.created_at).toLocaleString()}
                      </td>
                      {/* Action badge */}
                      <td className="table-td">
                        <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold ring-1 ring-inset ${
                          ACTION_STYLES[log.action] ?? 'bg-slate-100 text-slate-600 ring-slate-200/60'
                        }`}>
                          {log.action.replace(/_/g, ' ')}
                        </span>
                      </td>
                      {/* Actor */}
                      <td className="table-td font-mono text-xs text-slate-500">
                        {log.actor_id ? log.actor_id.slice(0, 8) + '…' : <span className="text-slate-300">—</span>}
                      </td>
                      {/* Target */}
                      <td className="table-td text-xs">
                        {log.target_type && (
                          <span className="text-slate-400">{log.target_type}: </span>
                        )}
                        <span className="font-mono text-slate-700">
                          {log.target_id ? log.target_id.slice(0, 10) + '…' : <span className="text-slate-300">—</span>}
                        </span>
                      </td>
                      {/* IP */}
                      <td className="table-td text-xs text-slate-400 font-mono">
                        {log.ip_address ?? <span className="text-slate-300">—</span>}
                      </td>
                      {/* Details */}
                      <td className="table-td max-w-xs">
                        {log.metadata && Object.keys(log.metadata).length > 0 ? (
                          <details className="text-xs text-slate-500">
                            <summary className="cursor-pointer font-medium text-indigo-600 hover:text-indigo-800">
                              View
                            </summary>
                            <pre className="mt-2 rounded-lg border border-slate-100 bg-slate-50 p-2.5 text-[11px] leading-relaxed text-slate-600">
                              {JSON.stringify(log.metadata, null, 2)}
                            </pre>
                          </details>
                        ) : <span className="text-slate-300">—</span>}
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
            total={logs.length + (page - 1) * PAGE_SIZE}
            onPage={(p) => { setPage(p); load(p) }}
          />
        </div>
      </div>
    </div>
  )
}
