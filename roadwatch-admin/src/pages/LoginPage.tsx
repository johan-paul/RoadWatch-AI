import { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { adminLogin } from '../api/services'
import { useAuth } from '../contexts/AuthContext'
import { AlertCircle, Construction, Eye, EyeOff, Lock, Phone } from 'lucide-react'

const features = [
  { icon: '⚡', text: 'Real-time complaint tracking and routing' },
  { icon: '🤖', text: 'AI-powered road damage classification' },
  { icon: '📍', text: 'Geo-tagged officer field assignments' },
  { icon: '📊', text: 'Analytics dashboard and audit logs' },
]

export function LoginPage() {
  const navigate   = useNavigate()
  const { login }  = useAuth()

  const [phone,      setPhone]      = useState('')
  const [secret,     setSecret]     = useState('')
  const [showSecret, setShowSecret] = useState(false)
  const [loading,    setLoading]    = useState(false)
  const [error,      setError]      = useState('')

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    setLoading(true)
    setError('')
    try {
      const data = await adminLogin(phone, secret)
      login(data)
      navigate('/', { replace: true })
    } catch (err: any) {
      setError(err.response?.data?.detail ?? 'Invalid credentials. Please try again.')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="flex min-h-screen">

      {/* ── Left branding panel ────────────────────────────────────────────── */}
      <div className="relative hidden lg:flex w-[440px] shrink-0 flex-col items-center justify-center overflow-hidden bg-[#0d1424] p-12">
        {/* Ambient glows */}
        <div className="pointer-events-none absolute -top-40 -left-24 h-96 w-96 rounded-full bg-indigo-600/20 blur-3xl" />
        <div className="pointer-events-none absolute -bottom-24 -right-16 h-80 w-80 rounded-full bg-violet-700/15 blur-3xl" />
        <div className="pointer-events-none absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 h-[500px] w-[500px] rounded-full bg-slate-700/20 blur-3xl" />

        <div className="relative z-10 w-full max-w-xs">
          {/* Logo */}
          <div className="mb-10">
            <div className="mb-5 flex h-14 w-14 items-center justify-center rounded-2xl bg-gradient-to-br from-indigo-500 to-violet-600 shadow-2xl shadow-indigo-500/40">
              <Construction size={26} className="text-white" />
            </div>
            <h1 className="text-3xl font-bold tracking-tight text-white">RoadWatch AI</h1>
            <p className="mt-2.5 text-sm leading-relaxed text-slate-400">
              Intelligent road hazard monitoring and transparent governance for smarter cities.
            </p>
          </div>

          {/* Feature list */}
          <div className="space-y-3.5 border-t border-slate-800 pt-7">
            {features.map(({ icon, text }) => (
              <div key={text} className="flex items-start gap-3">
                <span className="mt-0.5 shrink-0 text-base">{icon}</span>
                <span className="text-sm leading-relaxed text-slate-400">{text}</span>
              </div>
            ))}
          </div>

          {/* Version badge */}
          <div className="mt-10 flex items-center gap-2">
            <span className="inline-flex items-center rounded-full bg-indigo-500/15 px-2.5 py-1 text-[10px] font-semibold uppercase tracking-wider text-indigo-400 ring-1 ring-inset ring-indigo-500/20">
              v1.0.0
            </span>
            <span className="text-[11px] text-slate-600">Secure admin access</span>
          </div>
        </div>
      </div>

      {/* ── Right form panel ───────────────────────────────────────────────── */}
      <div className="flex flex-1 flex-col items-center justify-center bg-slate-50 p-8">
        <div className="w-full max-w-[360px]">

          {/* Mobile-only logo */}
          <div className="mb-8 flex items-center gap-3 lg:hidden">
            <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-gradient-to-br from-indigo-500 to-violet-600 shadow-md shadow-indigo-500/30">
              <Construction size={17} className="text-white" />
            </div>
            <span className="font-bold text-slate-900">RoadWatch AI</span>
          </div>

          {/* Heading */}
          <div className="mb-8">
            <h2 className="text-2xl font-bold text-slate-900">Welcome back</h2>
            <p className="mt-1 text-sm text-slate-500">
              Sign in to your administrator account
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-5">
            {/* Phone */}
            <div>
              <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-slate-600">
                Phone Number
              </label>
              <div className="relative">
                <Phone
                  size={15}
                  className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"
                />
                <input
                  type="tel"
                  className="input pl-10"
                  placeholder="+919487896921"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  required
                  autoFocus
                />
              </div>
            </div>

            {/* Secret */}
            <div>
              <label className="mb-1.5 block text-xs font-semibold uppercase tracking-wide text-slate-600">
                Admin Secret
              </label>
              <div className="relative">
                <Lock
                  size={15}
                  className="absolute left-3.5 top-1/2 -translate-y-1/2 text-slate-400"
                />
                <input
                  type={showSecret ? 'text' : 'password'}
                  className="input pl-10 pr-10"
                  placeholder="Your admin secret key"
                  value={secret}
                  onChange={(e) => setSecret(e.target.value)}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowSecret(!showSecret)}
                  className="absolute right-3.5 top-1/2 -translate-y-1/2 text-slate-400 transition hover:text-slate-600"
                >
                  {showSecret ? <EyeOff size={15} /> : <Eye size={15} />}
                </button>
              </div>
            </div>

            {/* Error */}
            {error && (
              <div className="flex items-center gap-2.5 rounded-xl border border-red-100 bg-red-50 px-4 py-3 text-sm text-red-700">
                <AlertCircle size={15} className="shrink-0" />
                {error}
              </div>
            )}

            {/* Submit */}
            <button
              type="submit"
              disabled={loading}
              className="btn-primary w-full justify-center py-3 text-sm"
            >
              {loading ? (
                <>
                  <span className="h-4 w-4 animate-spin rounded-full border-2 border-white border-t-transparent" />
                  Signing in…
                </>
              ) : (
                'Sign In →'
              )}
            </button>
          </form>

          <p className="mt-8 text-center text-[11px] text-slate-400">
            RoadWatch AI · Authorised admin access only
          </p>
        </div>
      </div>
    </div>
  )
}
