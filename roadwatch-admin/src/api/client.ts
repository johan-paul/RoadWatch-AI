import axios from 'axios'
import type { TokenResponse } from './types'

export const BASE_URL = 'http://localhost:8000/api/v1'

const client = axios.create({
  baseURL: BASE_URL,
  headers: { 'Content-Type': 'application/json' },
})

// ── Request interceptor — attach access token ─────────────────────────────────
client.interceptors.request.use((config) => {
  const token = localStorage.getItem('access_token')
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

// ── Response interceptor — auto-refresh on 401 ───────────────────────────────
let _refreshing = false
let _queue: Array<(token: string) => void> = []

client.interceptors.response.use(
  (res) => res,
  async (error) => {
    const original = error.config

    if (error.response?.status === 401 && !original._retry) {
      original._retry = true

      if (_refreshing) {
        // Queue this request until refresh completes
        return new Promise((resolve) => {
          _queue.push((token) => {
            original.headers.Authorization = `Bearer ${token}`
            resolve(client(original))
          })
        })
      }

      _refreshing = true
      const refreshToken = localStorage.getItem('refresh_token')

      if (!refreshToken) {
        _clearAuth()
        window.location.href = '/login'
        return Promise.reject(error)
      }

      try {
        const { data } = await axios.post<TokenResponse>(`${BASE_URL}/auth/refresh`, {
          refresh_token: refreshToken,
        })
        localStorage.setItem('access_token', data.access_token)
        localStorage.setItem('refresh_token', data.refresh_token)

        _queue.forEach((cb) => cb(data.access_token))
        _queue = []
        _refreshing = false

        original.headers.Authorization = `Bearer ${data.access_token}`
        return client(original)
      } catch {
        _refreshing = false
        _queue = []
        _clearAuth()
        window.location.href = '/login'
        return Promise.reject(error)
      }
    }

    return Promise.reject(error)
  },
)

function _clearAuth() {
  localStorage.removeItem('access_token')
  localStorage.removeItem('refresh_token')
  localStorage.removeItem('admin_user')
}

export default client
