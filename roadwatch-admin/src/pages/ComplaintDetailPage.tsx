import { useEffect, useState } from 'react'
import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft, UserCheck, Bot, Users, Info, Flame } from 'lucide-react'
import { listComplaints, escalateComplaint } from '../api/services'
import { Badge, statusVariant, severityVariant, statusLabel } from '../components/ui/Badge'
import { ReassignModal } from '../components/ReassignModal'
import type { Complaint } from '../api/types'

export function ComplaintDetailPage() {
  const { id } = useParams<{ id: string }>()
  const navigate = useNavigate()
  const [complaint, setComplaint] = useState<Complaint | null>(null)
  const [loading, setLoading]     = useState(true)
  const [showReassign, setShowReassign]   = useState(false)
  const [escalating, setEscalating]       = useState(false)

  const handleEscalate = async () => {
    if (!confirm('Escalate this complaint to emergency? The officer will receive an urgent FCM alert.')) return
    setEscalating(true)
    try {
      await escalateComplaint(complaint!.id)
      load()
    } catch (e: any) {
      alert(e.response?.data?.detail ?? 'Failed to escalate.')
    } finally {
      setEscalating(false)
    }
  }

  const load = () => {
    listComplaints(undefined, undefined, 1, 200)
      .then((data) => setComplaint(data.find((c) => c.id === id) ?? null))
      .finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [id])

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-[3px] border-indigo-600 border-t-transparent" />
      </div>
    )
  }

  if (!complaint) {
    return (
      <div className="p-8">
        <button onClick={() => navigate(-1)} className="btn-secondary mb-6">
          <ArrowLeft size={14} /> Back
        </button>
        <p className="text-slate-500">Complaint not found.</p>
      </div>
    )
  }

  const canReassign = !['resolved', 'rejected', 'duplicate'].includes(complaint.status)

  return (
    <div>
      {/* ── Sticky header ───────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div className="flex items-center gap-3">
            <button
              onClick={() => navigate(-1)}
              className="flex h-8 w-8 items-center justify-center rounded-xl border border-slate-200 bg-white text-slate-500 shadow-sm transition hover:bg-slate-50 hover:text-slate-800"
            >
              <ArrowLeft size={15} />
            </button>
            <div>
              <h1 className="page-title capitalize">
                {complaint.damage_type?.replace(/_/g, ' ') ?? 'Complaint Detail'}
              </h1>
              <p className="page-sub font-mono">{complaint.id}</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {complaint.severity && (
              <Badge label={complaint.severity} variant={severityVariant(complaint.severity)} />
            )}
            <Badge label={statusLabel(complaint.status)} variant={statusVariant(complaint.status)} />
            {!['resolved','rejected','duplicate'].includes(complaint.status) && (
              <button
                onClick={handleEscalate}
                disabled={escalating}
                className="inline-flex items-center gap-1.5 rounded-lg bg-red-50 px-3 py-1.5 text-xs font-semibold text-red-700 ring-1 ring-inset ring-red-200 transition hover:bg-red-100 disabled:opacity-50"
              >
                <Flame size={12} />
                {escalating ? 'Escalating…' : 'Escalate'}
              </button>
            )}
          </div>
        </div>
      </div>

      <div className="p-8">
        <div className="grid grid-cols-1 gap-6 xl:grid-cols-3">

          {/* ── Main column ─────────────────────────────────────────────── */}
          <div className="space-y-6 xl:col-span-2">

            {/* Info card */}
            <div className="card p-6">
              <h2 className="mb-4 text-xs font-semibold uppercase tracking-wider text-slate-400">
                Location &amp; Description
              </h2>
              <p className="flex items-start gap-2 text-sm text-slate-700">
                <span className="mt-0.5 shrink-0">📍</span>
                {complaint.location_address ?? `${complaint.location_lat}, ${complaint.location_lng}`}
              </p>
              {complaint.description && (
                <p className="mt-3 text-sm leading-relaxed text-slate-600">{complaint.description}</p>
              )}
              {canReassign && (
                <button onClick={() => setShowReassign(true)} className="btn-primary mt-5">
                  <UserCheck size={14} />
                  Reassign to Officer
                </button>
              )}
            </div>

            {/* Photo */}
            {complaint.image_url && (
              <div className="card overflow-hidden">
                <div className="border-b border-slate-100 px-5 py-3">
                  <p className="text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                    Before Photo
                  </p>
                </div>
                <img
                  src={complaint.image_url}
                  alt="Complaint"
                  className="w-full object-cover"
                  style={{ maxHeight: 420 }}
                />
              </div>
            )}
          </div>

          {/* ── Side panel ──────────────────────────────────────────────── */}
          <div className="space-y-4">

            {/* AI Analysis */}
            <div className="card p-5">
              <div className="mb-4 flex items-center gap-2">
                <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-indigo-50">
                  <Bot size={14} className="text-indigo-600" />
                </div>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                  AI Analysis
                </h3>
              </div>
              <div className="space-y-4">
                {/* Confidence */}
                {complaint.ai_confidence_score != null && (
                  <div>
                    <div className="mb-1.5 flex items-center justify-between">
                      <span className="text-xs text-slate-400">Confidence</span>
                      <span className={`text-xs font-semibold ${
                        complaint.ai_confidence_score >= 0.70 ? 'text-emerald-600' :
                        complaint.ai_confidence_score >= 0.45 ? 'text-amber-600' : 'text-red-600'
                      }`}>
                        {(complaint.ai_confidence_score * 100).toFixed(0)}%
                      </span>
                    </div>
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-slate-100">
                      <div
                        className={`h-1.5 rounded-full transition-all ${
                          complaint.ai_confidence_score >= 0.70 ? 'bg-emerald-500' :
                          complaint.ai_confidence_score >= 0.45 ? 'bg-amber-500' : 'bg-red-500'
                        }`}
                        style={{ width: `${complaint.ai_confidence_score * 100}%` }}
                      />
                    </div>
                  </div>
                )}
                {/* Risk Score */}
                {complaint.ai_risk_score != null && (
                  <div>
                    <div className="mb-1.5 flex items-center justify-between">
                      <span className="text-xs text-slate-400">Risk Score</span>
                      <span className={`text-xs font-semibold ${
                        complaint.ai_risk_score >= 0.70 ? 'text-red-600' :
                        complaint.ai_risk_score >= 0.50 ? 'text-amber-600' : 'text-emerald-600'
                      }`}>
                        {(complaint.ai_risk_score * 100).toFixed(0)}%
                      </span>
                    </div>
                    <div className="h-1.5 w-full overflow-hidden rounded-full bg-slate-100">
                      <div
                        className={`h-1.5 rounded-full transition-all ${
                          complaint.ai_risk_score >= 0.70 ? 'bg-red-500' :
                          complaint.ai_risk_score >= 0.50 ? 'bg-amber-500' : 'bg-emerald-500'
                        }`}
                        style={{ width: `${complaint.ai_risk_score * 100}%` }}
                      />
                    </div>
                  </div>
                )}
                <Row
                  label="Duplicate"
                  value={complaint.is_duplicate ? 'Yes' : 'No'}
                  valueClass={complaint.is_duplicate ? 'text-red-600' : undefined}
                />
              </div>
            </div>

            {/* Community */}
            <div className="card p-5">
              <div className="mb-4 flex items-center gap-2">
                <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-emerald-50">
                  <Users size={14} className="text-emerald-600" />
                </div>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                  Community
                </h3>
              </div>
              <div className="space-y-2.5">
                <Row label="Confirmations" value={String(complaint.confirmation_count)} />
                <Row label="Rejections"    value={String(complaint.rejection_count)} />
                <Row
                  label="Verified Score"
                  value={complaint.verified_confidence_score != null
                    ? `${(complaint.verified_confidence_score * 100).toFixed(0)}%`
                    : '—'}
                />
              </div>
            </div>

            {/* Details */}
            <div className="card p-5">
              <div className="mb-4 flex items-center gap-2">
                <div className="flex h-7 w-7 items-center justify-center rounded-lg bg-slate-100">
                  <Info size={14} className="text-slate-500" />
                </div>
                <h3 className="text-xs font-semibold uppercase tracking-wider text-slate-500">
                  Timeline
                </h3>
              </div>
              <div className="space-y-2.5">
                <Row label="Reported" value={new Date(complaint.created_at).toLocaleString()} />
                <Row label="Updated"  value={new Date(complaint.updated_at).toLocaleString()} />
                {complaint.assigned_officer_id && (
                  <Row label="Officer" value={complaint.assigned_officer_id.slice(0, 8) + '…'} />
                )}
              </div>
              {complaint.resolution_notes && (
                <div className="mt-3 rounded-xl border border-slate-100 bg-slate-50 px-3 py-2.5">
                  <p className="mb-1 text-[11px] font-semibold uppercase tracking-wider text-slate-400">
                    Resolution Notes
                  </p>
                  <p className="text-xs leading-relaxed text-slate-600">{complaint.resolution_notes}</p>
                </div>
              )}
            </div>

          </div>
        </div>
      </div>

      {showReassign && (
        <ReassignModal
          complaintId={complaint.id}
          onClose={() => setShowReassign(false)}
          onDone={() => { setShowReassign(false); load() }}
        />
      )}
    </div>
  )
}

function Row({
  label,
  value,
  valueClass,
}: {
  label: string
  value: string
  valueClass?: string
}) {
  return (
    <div className="flex items-center justify-between gap-2">
      <span className="text-xs text-slate-400">{label}</span>
      <span className={`text-xs font-medium text-slate-800 ${valueClass ?? ''}`}>{value}</span>
    </div>
  )
}
