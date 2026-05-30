import { useEffect, useState } from 'react'
import { Plus, Pencil, Trash2, RefreshCw, ShieldCheck } from 'lucide-react'
import { listOfficers, deleteOfficer } from '../api/services'
import { OfficerModal } from '../components/OfficerModal'
import type { Officer } from '../api/types'

export function OfficersPage() {
  const [officers, setOfficers] = useState<Officer[]>([])
  const [loading, setLoading]   = useState(true)
  const [modal, setModal]       = useState<'create' | Officer | null>(null)
  const [deleting, setDeleting] = useState<string | null>(null)

  const load = () => {
    setLoading(true)
    listOfficers().then(setOfficers).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  const handleDelete = async (officer: Officer) => {
    if (!confirm(`Delete officer ${officer.user.name}? This cannot be undone.`)) return
    setDeleting(officer.id)
    try {
      await deleteOfficer(officer.id)
      load()
    } finally {
      setDeleting(null)
    }
  }

  return (
    <div>
      {/* ── Sticky header ───────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Officers</h1>
            <p className="page-sub">Manage field officers and their assignments</p>
          </div>
          <div className="flex items-center gap-2">
            <button onClick={load} className="btn-secondary">
              <RefreshCw size={14} />
            </button>
            <button onClick={() => setModal('create')} className="btn-primary">
              <Plus size={14} />
              Add Officer
            </button>
          </div>
        </div>
      </div>

      <div className="p-8">
        <div className="card overflow-hidden">
          <div className="overflow-x-auto">
            <table className="w-full">
              <thead>
                <tr>
                  <th className="table-th">Name</th>
                  <th className="table-th">Phone</th>
                  <th className="table-th">Employee ID</th>
                  <th className="table-th">Department</th>
                  <th className="table-th">Ward / Area</th>
                  <th className="table-th">Zone</th>
                  <th className="table-th">Workload</th>
                  <th className="table-th">Status</th>
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
                ) : officers.length === 0 ? (
                  <tr>
                    <td colSpan={9} className="py-20 text-center">
                      <div className="flex flex-col items-center gap-3">
                        <div className="flex h-12 w-12 items-center justify-center rounded-2xl bg-indigo-50">
                          <ShieldCheck size={22} className="text-indigo-500" />
                        </div>
                        <p className="text-sm font-medium text-slate-500">No officers yet</p>
                        <p className="text-xs text-slate-400">Click "Add Officer" to create one</p>
                      </div>
                    </td>
                  </tr>
                ) : (
                  officers.map((o) => (
                    <tr key={o.id} className="table-tr">
                      {/* Name */}
                      <td className="table-td">
                        <div className="flex items-center gap-3">
                          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gradient-to-br from-indigo-500 to-violet-600 text-[11px] font-bold text-white shadow-sm shadow-indigo-200">
                            {o.user.name[0].toUpperCase()}
                          </div>
                          <span className="font-medium text-slate-900">{o.user.name}</span>
                        </div>
                      </td>
                      {/* Phone */}
                      <td className="table-td text-slate-500">{o.user.phone_number}</td>
                      {/* Employee ID */}
                      <td className="table-td font-mono text-xs text-slate-500">
                        {o.employee_id ?? <span className="text-slate-300">—</span>}
                      </td>
                      {/* Department */}
                      <td className="table-td">
                        {o.department ?? <span className="text-slate-300">—</span>}
                      </td>
                      {/* Ward / Area */}
                      <td className="table-td">
                        {o.ward_number ? (
                          <span>
                            <span className="font-medium text-slate-900">{o.ward_number}</span>
                            {o.area_name && (
                              <span className="ml-1.5 text-xs text-slate-400">{o.area_name}</span>
                            )}
                          </span>
                        ) : <span className="text-slate-300">—</span>}
                      </td>
                      {/* Zone */}
                      <td className="table-td">
                        {o.zone ? (
                          <span className="inline-flex items-center rounded-full bg-slate-100 px-2.5 py-0.5 text-[11px] font-medium text-slate-600">
                            {o.zone}
                          </span>
                        ) : <span className="text-slate-300">—</span>}
                      </td>
                      {/* Workload */}
                      <td className="table-td">
                        <span className={`font-semibold ${o.workload_count > 5 ? 'text-red-600' : 'text-slate-900'}`}>
                          {o.workload_count}
                        </span>
                      </td>
                      {/* Status */}
                      <td className="table-td">
                        <span className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold ring-1 ring-inset ${
                          o.user.is_suspended
                            ? 'bg-red-50 text-red-700 ring-red-200/60'
                            : 'bg-emerald-50 text-emerald-700 ring-emerald-200/60'
                        }`}>
                          {o.user.is_suspended ? 'Suspended' : 'Active'}
                        </span>
                      </td>
                      {/* Actions */}
                      <td className="table-td">
                        <div className="flex gap-1">
                          <button
                            onClick={() => setModal(o)}
                            className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 transition hover:bg-indigo-50 hover:text-indigo-600"
                            title="Edit"
                          >
                            <Pencil size={13} />
                          </button>
                          <button
                            onClick={() => handleDelete(o)}
                            disabled={deleting === o.id}
                            className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 transition hover:bg-red-50 hover:text-red-600 disabled:opacity-40"
                            title="Delete"
                          >
                            <Trash2 size={13} />
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
      </div>

      {modal && (
        <OfficerModal
          officer={modal === 'create' ? undefined : modal}
          onClose={() => setModal(null)}
          onSaved={() => { setModal(null); load() }}
        />
      )}
    </div>
  )
}
