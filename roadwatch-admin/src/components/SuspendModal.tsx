import { useState } from 'react'
import { Modal } from './ui/Modal'
import { suspendUser } from '../api/services'

interface Props {
  userId: string
  userName: string
  onClose: () => void
  onDone: () => void
}

export function SuspendModal({ userId, userName, onClose, onDone }: Props) {
  const [reason, setReason] = useState('')
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      await suspendUser(userId, reason || undefined)
      onDone()
    } catch (err: any) {
      setError(err.response?.data?.detail ?? 'Failed to suspend.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal title={`Suspend ${userName}`} onClose={onClose} size="sm">
      <form onSubmit={handleSubmit} className="space-y-4">
        <p className="text-sm text-slate-600">
          This will immediately revoke all active sessions for <strong>{userName}</strong>.
        </p>
        <div>
          <label className="mb-1 block text-xs font-medium text-slate-700">Reason (optional)</label>
          <textarea
            className="input resize-none"
            rows={3}
            placeholder="Reason for suspension…"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
          />
        </div>

        {error && <p className="rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">{error}</p>}

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
          <button type="submit" disabled={loading} className="btn-danger">
            {loading ? 'Suspending…' : 'Suspend User'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
