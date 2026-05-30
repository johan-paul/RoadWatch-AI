import { useEffect, useState } from 'react'
import { RefreshCw, IndianRupee, TrendingUp, CheckCircle, Clock, AlertTriangle } from 'lucide-react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts'
import { getBudget } from '../api/services'

const TYPE_COLORS: Record<string, string> = {
  pothole:      '#ef4444',
  crack:        '#f59e0b',
  waterlogging: '#3b82f6',
  damaged_road: '#8b5cf6',
  other:        '#94a3b8',
}

function inr(n: number) {
  if (n >= 10_00_000) return `₹${(n / 10_00_000).toFixed(1)}L`
  if (n >= 1_000)     return `₹${(n / 1_000).toFixed(0)}K`
  return `₹${n}`
}

export function BudgetPage() {
  const [data, setData]     = useState<any>(null)
  const [loading, setLoading] = useState(true)

  const load = () => {
    setLoading(true)
    getBudget().then(setData).finally(() => setLoading(false))
  }

  useEffect(() => { load() }, [])

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-[3px] border-indigo-600 border-t-transparent" />
      </div>
    )
  }

  const s = data?.summary ?? {}
  const byType: any[] = data?.by_damage_type ?? []
  const monthly: any[] = data?.monthly_trend ?? []

  return (
    <div>
      {/* ── Sticky header ─────────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Repair Budget</h1>
            <p className="page-sub">Estimated repair costs based on complaint data</p>
          </div>
          <button onClick={load} className="btn-secondary">
            <RefreshCw size={14} /> Refresh
          </button>
        </div>
      </div>

      <div className="p-8 space-y-6">
        {/* ── Summary cards ─────────────────────────────────────────────── */}
        <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
          <_SummaryCard
            title="Total Estimated"
            value={inr(s.total_estimated_inr ?? 0)}
            icon={IndianRupee}
            color="indigo"
            sub="All open + resolved"
          />
          <_SummaryCard
            title="Resolved Cost"
            value={inr(s.resolved_cost_inr ?? 0)}
            icon={CheckCircle}
            color="green"
            sub={`${s.resolution_rate_pct ?? 0}% of total`}
          />
          <_SummaryCard
            title="In Progress"
            value={inr(s.in_progress_cost_inr ?? 0)}
            icon={TrendingUp}
            color="amber"
            sub="Currently being repaired"
          />
          <_SummaryCard
            title="Pending"
            value={inr(s.pending_cost_inr ?? 0)}
            icon={Clock}
            color="red"
            sub="Awaiting repair"
          />
        </div>

        {/* ── Resolution rate bar ────────────────────────────────────────── */}
        <div className="card p-5">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-sm font-semibold text-slate-900">Budget Resolution Rate</p>
            <span className="text-sm font-bold text-emerald-600">
              {s.resolution_rate_pct ?? 0}%
            </span>
          </div>
          <div className="h-3 w-full overflow-hidden rounded-full bg-slate-100">
            <div
              className="h-3 rounded-full bg-gradient-to-r from-emerald-400 to-emerald-600 transition-all"
              style={{ width: `${Math.min(s.resolution_rate_pct ?? 0, 100)}%` }}
            />
          </div>
          <p className="mt-2 text-xs text-slate-400">
            {inr(s.resolved_cost_inr ?? 0)} resolved of {inr(s.total_estimated_inr ?? 0)} estimated total
          </p>
        </div>

        <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
          {/* ── Cost by damage type ─────────────────────────────────────── */}
          <div className="card p-5">
            <p className="mb-1 text-sm font-semibold text-slate-900">Cost by Damage Type</p>
            <p className="mb-4 text-[11px] text-slate-400">Estimated repair cost breakdown</p>
            <ResponsiveContainer width="100%" height={220}>
              <BarChart data={byType} barSize={40}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                <XAxis
                  dataKey="type"
                  tick={{ fontSize: 11, fill: '#94a3b8' }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={(v) => v.replace('_', ' ')}
                />
                <YAxis
                  tick={{ fontSize: 10, fill: '#94a3b8' }}
                  axisLine={false}
                  tickLine={false}
                  tickFormatter={(v) => inr(v)}
                />
                <Tooltip
                  formatter={(v: any) => [inr(v), 'Estimated Cost']}
                  contentStyle={{
                    borderRadius: 10,
                    border: '1px solid #e2e8f0',
                    fontSize: 12,
                  }}
                />
                <Bar dataKey="estimated_inr" radius={[6, 6, 0, 0]}>
                  {byType.map((e) => (
                    <Cell key={e.type} fill={TYPE_COLORS[e.type] ?? '#94a3b8'} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* ── Complaint type distribution ──────────────────────────────── */}
          <div className="card p-5">
            <p className="mb-1 text-sm font-semibold text-slate-900">Complaints by Type</p>
            <p className="mb-4 text-[11px] text-slate-400">Count and resolution status</p>
            <ResponsiveContainer width="100%" height={220}>
              <PieChart>
                <Pie
                  data={byType}
                  cx="50%" cy="50%"
                  innerRadius={55}
                  outerRadius={85}
                  paddingAngle={3}
                  dataKey="count"
                  nameKey="type"     /* use `type` as the slice name (no `name` field exists) */
                  label={({ name, percent }: any) =>
                    name && percent > 0.05
                      ? `${String(name).replace(/_/g, ' ')} ${(percent * 100).toFixed(0)}%`
                      : ''
                  }
                  labelLine={false}
                >
                  {byType.map((e) => (
                    <Cell key={e.type} fill={TYPE_COLORS[e.type] ?? '#94a3b8'} />
                  ))}
                </Pie>
                <Tooltip
                  formatter={(v: any, _name: any, props: any) => [
                    `${v} complaints — ${inr(props?.payload?.estimated_inr ?? 0)}`,
                    String(props?.payload?.type ?? '').replace(/_/g, ' '),
                  ]}
                  contentStyle={{ borderRadius: 10, border: '1px solid #e2e8f0', fontSize: 12 }}
                />
                <Legend
                  iconType="circle"
                  iconSize={8}
                  wrapperStyle={{ fontSize: 12, color: '#64748b' }}
                  formatter={(value: any) => String(value ?? '').replace(/_/g, ' ')}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>

          {/* ── Detailed breakdown table ─────────────────────────────────── */}
          <div className="card overflow-hidden xl:col-span-2">
            <div className="border-b border-slate-100 px-5 py-4">
              <p className="text-sm font-semibold text-slate-900">Detailed Breakdown</p>
            </div>
            <table className="w-full">
              <thead>
                <tr>
                  <th className="table-th">Damage Type</th>
                  <th className="table-th">Total Complaints</th>
                  <th className="table-th">Resolved</th>
                  <th className="table-th">Resolution Rate</th>
                  <th className="table-th">Estimated Cost</th>
                </tr>
              </thead>
              <tbody>
                {byType.map((row) => (
                  <tr key={row.type} className="table-tr">
                    <td className="table-td">
                      <div className="flex items-center gap-2.5">
                        <div
                          className="h-2.5 w-2.5 rounded-full"
                          style={{ backgroundColor: TYPE_COLORS[row.type] ?? '#94a3b8' }}
                        />
                        <span className="capitalize">{row.type.replace('_', ' ')}</span>
                      </div>
                    </td>
                    <td className="table-td font-medium">{row.count}</td>
                    <td className="table-td text-emerald-600 font-medium">{row.resolved}</td>
                    <td className="table-td">
                      <div className="flex items-center gap-2">
                        <div className="h-1.5 w-20 overflow-hidden rounded-full bg-slate-100">
                          <div
                            className="h-1.5 rounded-full bg-emerald-500"
                            style={{ width: `${row.count > 0 ? (row.resolved / row.count * 100) : 0}%` }}
                          />
                        </div>
                        <span className="text-xs text-slate-500">
                          {row.count > 0 ? Math.round(row.resolved / row.count * 100) : 0}%
                        </span>
                      </div>
                    </td>
                    <td className="table-td font-semibold text-indigo-600">
                      {inr(row.estimated_inr)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>

        <p className="text-center text-[11px] text-slate-400">
          * Costs are estimates based on standard repair rates. Actual costs may vary.
        </p>
      </div>
    </div>
  )
}

function _SummaryCard({
  title, value, icon: Icon, color, sub,
}: {
  title: string
  value: string
  icon: React.ElementType
  color: 'indigo' | 'green' | 'amber' | 'red'
  sub?: string
}) {
  const map = {
    indigo: { border: 'border-l-indigo-500', icon: 'bg-indigo-50 text-indigo-600' },
    green:  { border: 'border-l-emerald-500', icon: 'bg-emerald-50 text-emerald-600' },
    amber:  { border: 'border-l-amber-500',   icon: 'bg-amber-50 text-amber-600' },
    red:    { border: 'border-l-red-500',     icon: 'bg-red-50 text-red-600' },
  }
  const c = map[color]
  return (
    <div className={`card border-l-4 ${c.border} p-5`}>
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-[11px] font-semibold uppercase tracking-wider text-slate-500">{title}</p>
          <p className="mt-1.5 text-2xl font-bold tracking-tight text-slate-900">{value}</p>
          {sub && <p className="mt-1 text-[11px] text-slate-400">{sub}</p>}
        </div>
        <div className={`shrink-0 rounded-xl p-2.5 ${c.icon}`}>
          <Icon size={20} />
        </div>
      </div>
    </div>
  )
}
