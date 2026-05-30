import type { LucideIcon } from 'lucide-react'

interface StatCardProps {
  title: string
  value: number | string
  icon: LucideIcon
  color: 'blue' | 'green' | 'amber' | 'red' | 'purple' | 'indigo'
  sub?: string
}

const colorMap = {
  blue:   { border: 'border-l-blue-500',    iconBg: 'bg-blue-50 text-blue-600',     val: 'text-slate-900' },
  green:  { border: 'border-l-emerald-500', iconBg: 'bg-emerald-50 text-emerald-600', val: 'text-slate-900' },
  amber:  { border: 'border-l-amber-500',   iconBg: 'bg-amber-50 text-amber-600',   val: 'text-slate-900' },
  red:    { border: 'border-l-red-500',     iconBg: 'bg-red-50 text-red-600',       val: 'text-slate-900' },
  purple: { border: 'border-l-violet-500',  iconBg: 'bg-violet-50 text-violet-600', val: 'text-slate-900' },
  indigo: { border: 'border-l-indigo-500',  iconBg: 'bg-indigo-50 text-indigo-600', val: 'text-slate-900' },
}

export function StatCard({ title, value, icon: Icon, color, sub }: StatCardProps) {
  const c = colorMap[color]
  return (
    <div className={`card border-l-4 ${c.border} p-5 transition-shadow hover:shadow-card-md`}>
      <div className="flex items-start justify-between gap-4">
        <div className="min-w-0 flex-1">
          <p className="text-[11px] font-semibold uppercase tracking-wider text-slate-500">{title}</p>
          <p className={`mt-1.5 text-3xl font-bold tracking-tight ${c.val}`}>{value}</p>
          {sub && <p className="mt-1 text-[11px] text-slate-400">{sub}</p>}
        </div>
        <div className={`shrink-0 rounded-xl p-2.5 ${c.iconBg}`}>
          <Icon size={20} />
        </div>
      </div>
    </div>
  )
}
