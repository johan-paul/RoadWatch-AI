import { ChevronLeft, ChevronRight } from 'lucide-react'

interface PaginationProps {
  page: number
  pageSize: number
  total: number
  onPage: (p: number) => void
}

export function Pagination({ page, pageSize, total, onPage }: PaginationProps) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize))
  if (totalPages <= 1) return null

  const from = Math.min((page - 1) * pageSize + 1, total)
  const to   = Math.min(page * pageSize, total)

  return (
    <div className="flex items-center justify-between border-t border-slate-100 px-5 py-3.5">
      <p className="text-[11px] text-slate-400">
        Showing <span className="font-medium text-slate-600">{from}–{to}</span> of{' '}
        <span className="font-medium text-slate-600">{total}</span>
      </p>
      <div className="flex items-center gap-1">
        <button
          onClick={() => onPage(page - 1)}
          disabled={page === 1}
          className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-700 disabled:opacity-30"
        >
          <ChevronLeft size={15} />
        </button>
        {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
          const p = Math.max(1, Math.min(page - 2, totalPages - 4)) + i
          return (
            <button
              key={p}
              onClick={() => onPage(p)}
              className={`flex h-7 min-w-[28px] items-center justify-center rounded-lg px-2 text-xs font-medium transition ${
                p === page
                  ? 'bg-indigo-600 text-white shadow-sm'
                  : 'text-slate-500 hover:bg-slate-100 hover:text-slate-800'
              }`}
            >
              {p}
            </button>
          )
        })}
        <button
          onClick={() => onPage(page + 1)}
          disabled={page === totalPages}
          className="flex h-7 w-7 items-center justify-center rounded-lg text-slate-400 transition hover:bg-slate-100 hover:text-slate-700 disabled:opacity-30"
        >
          <ChevronRight size={15} />
        </button>
      </div>
    </div>
  )
}
