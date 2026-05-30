import { useState } from 'react'
import { Modal } from './ui/Modal'
import { createOfficer, updateOfficer } from '../api/services'
import type { Officer } from '../api/types'

interface Props {
  officer?: Officer
  onClose: () => void
  onSaved: () => void
}

const ZONES = ['North', 'South', 'East', 'West', 'Central', 'North-East', 'North-West', 'South-East', 'South-West']

export function OfficerModal({ officer, onClose, onSaved }: Props) {
  const isEdit = !!officer

  const [form, setForm] = useState({
    phone_number: officer?.user.phone_number ?? '',
    name:         officer?.user.name          ?? '',
    employee_id:  officer?.employee_id        ?? '',
    department:   officer?.department         ?? '',
    ward_number:  officer?.ward_number        ?? '',
    area_name:    officer?.area_name          ?? '',
    zone:         officer?.zone               ?? '',
  })
  const [loading, setLoading] = useState(false)
  const [error,   setError]   = useState('')

  const set = (k: string, v: string) => setForm((f) => ({ ...f, [k]: v }))

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      const locationPayload = {
        ward_number: form.ward_number || undefined,
        area_name:   form.area_name   || undefined,
        zone:        form.zone        || undefined,
      }
      if (isEdit) {
        await updateOfficer(officer.id, {
          name:        form.name        || undefined,
          employee_id: form.employee_id || undefined,
          department:  form.department  || undefined,
          ...locationPayload,
        })
      } else {
        await createOfficer({
          phone_number: form.phone_number,
          name:         form.name,
          employee_id:  form.employee_id || undefined,
          department:   form.department  || undefined,
          ...locationPayload,
        })
      }
      onSaved()
    } catch (err: any) {
      setError(err.response?.data?.detail ?? 'An error occurred.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <Modal title={isEdit ? 'Edit Officer' : 'Create Officer'} onClose={onClose} size="lg">
      <form onSubmit={handleSubmit} className="space-y-5">
        {/* ── Identity ── */}
        <div className="grid grid-cols-2 gap-4">
          {!isEdit && (
            <div className="col-span-2">
              <label className="mb-1 block text-xs font-medium text-slate-700">Phone Number *</label>
              <input
                className="input"
                placeholder="+919876543210"
                value={form.phone_number}
                onChange={(e) => set('phone_number', e.target.value)}
                required
              />
            </div>
          )}
          <div className={isEdit ? 'col-span-2' : 'col-span-2'}>
            <label className="mb-1 block text-xs font-medium text-slate-700">Full Name *</label>
            <input
              className="input"
              placeholder="Officer name"
              value={form.name}
              onChange={(e) => set('name', e.target.value)}
              required
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-700">Employee ID</label>
            <input
              className="input"
              placeholder="EMP-001"
              value={form.employee_id}
              onChange={(e) => set('employee_id', e.target.value)}
            />
          </div>
          <div>
            <label className="mb-1 block text-xs font-medium text-slate-700">Department</label>
            <input
              className="input"
              placeholder="Public Works Dept"
              value={form.department}
              onChange={(e) => set('department', e.target.value)}
            />
          </div>
        </div>

        {/* ── Jurisdiction ── */}
        <div>
          <p className="mb-3 text-xs font-semibold uppercase tracking-wide text-slate-500">
            Jurisdiction / Area
          </p>
          <div className="grid grid-cols-3 gap-4">
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-700">Ward Number</label>
              <input
                className="input"
                placeholder="Ward 10 / W-10"
                value={form.ward_number}
                onChange={(e) => set('ward_number', e.target.value)}
              />
              <p className="mt-1 text-[10px] text-slate-400">Complaints in this ward are auto-assigned to this officer</p>
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-700">Area / Locality</label>
              <input
                className="input"
                placeholder="Perambur North"
                value={form.area_name}
                onChange={(e) => set('area_name', e.target.value)}
              />
            </div>
            <div>
              <label className="mb-1 block text-xs font-medium text-slate-700">Zone</label>
              <select
                className="input"
                value={form.zone}
                onChange={(e) => set('zone', e.target.value)}
              >
                <option value="">— Select zone —</option>
                {ZONES.map((z) => <option key={z} value={z}>{z}</option>)}
              </select>
            </div>
          </div>
        </div>

        {error && (
          <p className="rounded-lg bg-red-50 px-3 py-2 text-xs text-red-700">{error}</p>
        )}

        <div className="flex justify-end gap-2 pt-2">
          <button type="button" onClick={onClose} className="btn-secondary">Cancel</button>
          <button type="submit" disabled={loading} className="btn-primary">
            {loading ? 'Saving…' : isEdit ? 'Save Changes' : 'Create Officer'}
          </button>
        </div>
      </form>
    </Modal>
  )
}
