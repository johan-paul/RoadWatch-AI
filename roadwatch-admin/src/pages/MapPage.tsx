import { useEffect, useState } from 'react'
import { MapContainer, TileLayer, CircleMarker, Popup } from 'react-leaflet'
import { statusLabel } from '../components/ui/Badge'
import { listComplaints } from '../api/services'
import type { Complaint } from '../api/types'

const STATUS_COLORS: Record<string, string> = {
  pending:     '#f59e0b',
  assigned:    '#3b82f6',
  in_progress: '#8b5cf6',
  resolved:    '#10b981',
  rejected:    '#ef4444',
  duplicate:   '#94a3b8',
}

export function MapPage() {
  const [complaints, setComplaints] = useState<Complaint[]>([])
  const [loading, setLoading]       = useState(true)
  const [filter, setFilter]         = useState<string>('all')

  useEffect(() => {
    listComplaints(undefined, undefined, 1, 200)
      .then(setComplaints)
      .finally(() => setLoading(false))
  }, [])

  const filtered = filter === 'all' ? complaints : complaints.filter((c) => c.status === filter)

  const center: [number, number] = complaints.length > 0
    ? [complaints[0].location_lat, complaints[0].location_lng]
    : [20.5937, 78.9629]

  return (
    <div className="flex h-full flex-col">
      {/* ── Sticky header ─────────────────────────────────────────────────── */}
      <div className="page-header shrink-0">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Map View</h1>
            <p className="page-sub">
              {filtered.length} complaint{filtered.length !== 1 ? 's' : ''} plotted
            </p>
          </div>
          <select
            className="input w-auto text-xs"
            value={filter}
            onChange={(e) => setFilter(e.target.value)}
          >
            <option value="all">All Statuses</option>
            {['pending', 'assigned', 'in_progress', 'resolved', 'rejected'].map((s) => (
              <option key={s} value={s}>{statusLabel(s)}</option>
            ))}
          </select>
        </div>
      </div>

      {/* ── Legend ────────────────────────────────────────────────────────── */}
      <div className="shrink-0 border-b border-slate-200 bg-white px-8 py-3">
        <div className="flex flex-wrap items-center gap-4">
          {Object.entries(STATUS_COLORS).map(([s, color]) => (
            <div key={s} className="flex items-center gap-1.5">
              <div className="h-2.5 w-2.5 rounded-full" style={{ backgroundColor: color }} />
              <span className="text-[11px] font-medium text-slate-500">{statusLabel(s)}</span>
            </div>
          ))}
        </div>
      </div>

      {/* ── Map ───────────────────────────────────────────────────────────── */}
      <div className="relative flex-1 overflow-hidden">
        {loading ? (
          <div className="flex h-full items-center justify-center bg-slate-50">
            <div className="h-8 w-8 animate-spin rounded-full border-[3px] border-indigo-600 border-t-transparent" />
          </div>
        ) : (
          <MapContainer
            center={center}
            zoom={complaints.length > 0 ? 13 : 5}
            style={{ height: '100%', width: '100%' }}
          >
            <TileLayer
              attribution='&copy; <a href="https://openstreetmap.org">OpenStreetMap</a>'
              url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            {filtered.map((c) => (
              <CircleMarker
                key={c.id}
                center={[c.location_lat, c.location_lng]}
                radius={c.severity === 'high' ? 12 : c.severity === 'medium' ? 9 : 7}
                pathOptions={{
                  color: STATUS_COLORS[c.status] ?? '#94a3b8',
                  fillColor: STATUS_COLORS[c.status] ?? '#94a3b8',
                  fillOpacity: 0.78,
                  weight: 2,
                }}
              >
                <Popup>
                  <div className="min-w-[190px] text-xs">
                    <p className="mb-1.5 font-semibold capitalize text-slate-900">
                      {c.damage_type?.replace(/_/g, ' ') ?? 'Unknown type'}
                    </p>
                    <p className="text-slate-500">
                      {c.location_address ?? `${c.location_lat.toFixed(5)}, ${c.location_lng.toFixed(5)}`}
                    </p>
                    <div className="mt-2 flex flex-wrap gap-1">
                      <span className={`rounded-full px-2 py-0.5 text-[10px] font-semibold ring-1 ring-inset ${
                        c.severity === 'high'   ? 'bg-red-50 text-red-700 ring-red-200/60' :
                        c.severity === 'medium' ? 'bg-amber-50 text-amber-700 ring-amber-200/60' :
                                                   'bg-emerald-50 text-emerald-700 ring-emerald-200/60'
                      }`}>
                        {c.severity ?? 'unknown'}
                      </span>
                      <span className="rounded-full bg-slate-100 px-2 py-0.5 text-[10px] font-semibold text-slate-600 ring-1 ring-inset ring-slate-200/60">
                        {statusLabel(c.status)}
                      </span>
                    </div>
                    <p className="mt-1.5 text-[10px] text-slate-400">
                      {new Date(c.created_at).toLocaleDateString()}
                    </p>
                  </div>
                </Popup>
              </CircleMarker>
            ))}
          </MapContainer>
        )}
      </div>
    </div>
  )
}
