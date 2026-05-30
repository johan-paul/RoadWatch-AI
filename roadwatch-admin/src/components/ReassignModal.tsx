import { useEffect, useState } from 'react'
import { Modal } from './ui/Modal'
import { listOfficers, reassignComplaint } from '../api/services'
import type { Officer } from '../api/types'

interface Props {
  complaintId: string
  onClose: () => void
  onDone: () => void
}

export function ReassignModal({ complaintId, onClose, onDone }: Props) {
  const [officers, setOfficers] = useState<Officer[]>([])
  const [selected, setSelected] = useState('')
  const [reason, setReason] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  useEffect(() => {
    listOfficers().then(setOfficers)
  }, [])

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!selected) return
    setLoading(true)
    setError('')
    try {
      await reassignComplaint(complaintId, selected, reason || undefined)
      onDone()
    } catch (err: any) {
      setError(err.response?.data?.detail ?? 'Reassignment failed.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal title="Reassign Complaint" onClose={onClose}>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-700">Select Officer *</label>
          <select
            className="input"
            value={selected}
            onChange={(e) => setSelected(e.target.value)}
            required
          >
            <option value="">— Choose an officer —</option>
            {officers.map((o) => (
              <option key={o.id} value={o.id}>
                {o.user.name} ({o.department ?? 'No dept'}) — {o.workload_count} active
              </option>
            ))}
          </select>
        </div>
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-700">Reason (optional)</label>
          <textarea
            className="input resize-none"
            rows={3}
            placeholder="Reason for reassignment…"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
        </div>

        {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">{error}</p>}

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
          <button type="submit" disabled={loading || !selected} className="btn-primary">
            {loading ? 'Reassigning…' : 'Reassign'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
