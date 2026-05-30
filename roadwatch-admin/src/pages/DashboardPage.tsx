import { useEffect, useState } from 'react'
import {
  AlertTriangle, CheckCircle, FileText,
  Shield, Users, Clock,
} from 'lucide-react'
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, PieChart, Pie, Cell, Legend,
} from 'recharts'
import { getStats, listComplaints } from '../api/services'
import { StatCard } from '../components/ui/StatCard'
import type { AdminStats, Complaint } from '../api/types'

const STATUS_COLORS: Record<string, string> = {
  pending:     '#f59e0b',
  assigned:    '#3b82f6',
  in_progress: '#8b5cf6',
  resolved:    '#10b981',
  rejected:    '#ef4444',
  duplicate:   '#94a3b8',
}

export function DashboardPage() {
  const [stats, setStats]         = useState<AdminStats | null>(null)
  const [complaints, setComplaints] = useState<Complaint[]>([])
  const [loading, setLoading]     = useState(true)

  useEffect(() => {
    Promise.all([getStats(), listComplaints(undefined, undefined, 1, 200)])
      .then(([s, c]) => { setStats(s); setComplaints(c) })
      .finally(() => setLoading(false))
  }, [])

  const statusData = Object.entries(
    complaints.reduce<Record<string, number>>((acc, c) => {
      acc[c.status] = (acc[c.status] ?? 0) + 1
      return acc
    }, {}),
  ).map(([name, value]) => ({ name: name.replace('_', ' '), value }))

  const severityData = [
    { name: 'High',   value: complaints.filter((c) => c.severity === 'high').length,   color: '#ef4444' },
    { name: 'Medium', value: complaints.filter((c) => c.severity === 'medium').length, color: '#f59e0b' },
    { name: 'Low',    value: complaints.filter((c) => c.severity === 'low').length,    color: '#10b981' },
  ]

  const damageData = Object.entries(
    complaints.reduce<Record<string, number>>((acc, c) => {
      if (c.damage_type) acc[c.damage_type] = (acc[c.damage_type] ?? 0) + 1
      return acc
    }, {}),
  ).map(([name, value]) => ({ name: name.replace(/_/g, ' '), value }))

  if (loading) {
    return (
      <div className="flex h-full items-center justify-center">
        <div className="h-8 w-8 animate-spin rounded-full border-[3px] border-indigo-600 border-t-transparent" />
      </div>
    )
  }

  return (
    <div>
      {/* ── Sticky header ─────────────────────────────────────────────────── */}
      <div className="page-header">
        <div className="page-header-inner">
          <div>
            <h1 className="page-title">Dashboard</h1>
            <p className="page-sub">Live overview of RoadWatch AI platform activity</p>
          </div>
        </div>
      </div>

      <div className="p-8">
        {/* ── Stats grid ──────────────────────────────────────────────────── */}
        <div className="mb-8 grid grid-cols-2 gap-4 xl:grid-cols-3">
          <StatCard
            title="Total Complaints"
            value={stats?.total_complaints ?? 0}
            icon={FileText}
            color="blue"
          />
          <StatCard
            title="Pending"
            value={stats?.pending_complaints ?? 0}
            icon={Clock}
            color="amber"
            sub="Awaiting assignment"
          />
          <StatCard
            title="Resolved"
            value={stats?.resolved_complaints ?? 0}
            icon={CheckCircle}
            color="green"
          />
          <StatCard
            title="High Severity Open"
            value={stats?.high_severity_open ?? 0}
            icon={AlertTriangle}
            color="red"
            sub="Active high-priority issues"
          />
          <StatCard
            title="Total Officers"
            value={stats?.total_officers ?? 0}
            icon={Shield}
            color="indigo"
          />
          <StatCard
            title="Total Citizens"
            value={stats?.total_citizens ?? 0}
            icon={Users}
            color="purple"
          />
        </div>

        {/* ── Charts ──────────────────────────────────────────────────────── */}
        <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
          {/* Complaints by Status */}
          <div className="card p-5">
            <p className="mb-1 text-sm font-semibold text-slate-900">Complaints by Status</p>
            <p className="mb-4 text-[11px] text-slate-400">Distribution across all workflow stages</p>
            <ResponsiveContainer width="100%" height={210}>
              <BarChart data={statusData} barSize={32}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                <XAxis
                  dataKey="name"
                  tick={{ fontSize: 11, fill: '#94a3b8' }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fontSize: 11, fill: '#94a3b8' }}
                  axisLine={false}
                  tickLine={false}
                  allowDecimals={false}
                />
                <Tooltip
                  contentStyle={{
                    borderRadius: 10,
                    border: '1px solid #e2e8f0',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.08)',
                    fontSize: 12,
                  }}
                  cursor={{ fill: '#f8fafc' }}
                />
                <Bar dataKey="value" radius={[6, 6, 0, 0]}>
                  {statusData.map((entry) => (
                    <Cell
                      key={entry.name}
                      fill={STATUS_COLORS[entry.name.replace(' ', '_')] ?? '#94a3b8'}
                    />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>

          {/* Severity Distribution */}
          <div className="card p-5">
            <p className="mb-1 text-sm font-semibold text-slate-900">Severity Distribution</p>
            <p className="mb-4 text-[11px] text-slate-400">Issue urgency breakdown</p>
            <ResponsiveContainer width="100%" height={210}>
              <PieChart>
                <Pie
                  data={severityData}
                  cx="50%"
                  cy="50%"
                  innerRadius={58}
                  outerRadius={88}
                  paddingAngle={3}
                  dataKey="value"
                  label={({ name, percent }) =>
                    percent > 0.04 ? `${name} ${(percent * 100).toFixed(0)}%` : ''
                  }
                  labelLine={false}
                >
                  {severityData.map((entry) => (
                    <Cell key={entry.name} fill={entry.color} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    borderRadius: 10,
                    border: '1px solid #e2e8f0',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.08)',
                    fontSize: 12,
                  }}
                />
                <Legend
                  iconType="circle"
                  iconSize={8}
                  wrapperStyle={{ fontSize: 12, color: '#64748b' }}
                />
              </PieChart>
            </ResponsiveContainer>
          </div>

          {/* Damage Type */}
          <div className="card p-5 xl:col-span-2">
            <p className="mb-1 text-sm font-semibold text-slate-900">Complaints by Damage Type</p>
            <p className="mb-4 text-[11px] text-slate-400">AI-classified road issue categories</p>
            <ResponsiveContainer width="100%" height={190}>
              <BarChart data={damageData} barSize={44}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" vertical={false} />
                <XAxis
                  dataKey="name"
                  tick={{ fontSize: 11, fill: '#94a3b8' }}
                  axisLine={false}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fontSize: 11, fill: '#94a3b8' }}
                  axisLine={false}
                  tickLine={false}
                  allowDecimals={false}
                />
                <Tooltip
                  contentStyle={{
                    borderRadius: 10,
                    border: '1px solid #e2e8f0',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.08)',
                    fontSize: 12,
                  }}
                  cursor={{ fill: '#f8fafc' }}
                />
                <Bar dataKey="value" fill="#6366f1" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  )
}
