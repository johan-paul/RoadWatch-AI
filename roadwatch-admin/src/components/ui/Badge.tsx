interface BadgeProps {
  label: string
  variant?: 'default' | 'success' | 'warning' | 'danger' | 'info' | 'purple'
}

const variantClasses: Record<string, string> = {
  default: 'bg-slate-100 text-slate-600 ring-slate-200/60',
  success: 'bg-emerald-50 text-emerald-700 ring-emerald-200/60',
  warning: 'bg-amber-50 text-amber-700 ring-amber-200/60',
  danger:  'bg-red-50 text-red-700 ring-red-200/60',
  info:    'bg-blue-50 text-blue-700 ring-blue-200/60',
  purple:  'bg-violet-50 text-violet-700 ring-violet-200/60',
}

export function Badge({ label, variant = 'default' }: BadgeProps) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-[11px] font-semibold ring-1 ring-inset ${variantClasses[variant]}`}
    >
      {label}
    </span>
  )
}

// ── Helpers ───────────────────────────────────────────────────────────────────

export function statusVariant(status: string): BadgeProps['variant'] {
  const map: Record<string, BadgeProps['variant']> = {
    pending:     'warning',
    assigned:    'info',
    in_progress: 'purple',
    resolved:    'success',
    rejected:    'danger',
    duplicate:   'default',
  }
  return map[status] ?? 'default'
}

export function severityVariant(s: string): BadgeProps['variant'] {
  return s === 'high' ? 'danger' : s === 'medium' ? 'warning' : 'success'
}

export function statusLabel(s: string) {
  return s.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase())
}
