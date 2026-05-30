import client from './client'
import type {
  AdminStats, AuditLog, Complaint, ComplaintStatus,
  HeatmapPoint, Officer, SeverityLevel, TokenResponse, User,
} from './types'

// ── Auth ──────────────────────────────────────────────────────────────────────

export const adminLogin = (phone_number: string, admin_secret: string) =>
  client.post<TokenResponse>('/admin/auth/login', { phone_number, admin_secret })
    .then((r) => r.data)

export const adminRefresh = (refresh_token: string) =>
  client.post<TokenResponse>('/auth/refresh', { refresh_token })
    .then((r) => r.data)

// ── Stats ─────────────────────────────────────────────────────────────────────

export const getStats = () =>
  client.get<AdminStats>('/admin/stats').then((r) => r.data)

// ── Officers ──────────────────────────────────────────────────────────────────

export const listOfficers = () =>
  client.get<Officer[]>('/admin/officers').then((r) => r.data)

export const createOfficer = (body: {
  phone_number: string
  name: string
  employee_id?: string
  department?: string
  ward_number?: string
  area_name?: string
  zone?: string
}) => client.post<Officer>('/admin/officers', body).then((r) => r.data)

export const updateOfficer = (id: string, body: {
  name?: string
  employee_id?: string
  department?: string
  ward_number?: string
  area_name?: string
  zone?: string
}) => client.patch<Officer>(`/admin/officers/${id}`, body).then((r) => r.data)

export const deleteOfficer = (id: string) =>
  client.delete(`/admin/officers/${id}`)

// ── Users ─────────────────────────────────────────────────────────────────────

export const listUsers = (role?: string, page = 1, page_size = 50) =>
  client.get<User[]>('/admin/users', { params: { role, page, page_size } })
    .then((r) => r.data)

export const suspendUser = (id: string, reason?: string) =>
  client.post(`/admin/users/${id}/suspend`, { reason }).then((r) => r.data)

export const reinstateUser = (id: string) =>
  client.post(`/admin/users/${id}/reinstate`).then((r) => r.data)

// ── Complaints ────────────────────────────────────────────────────────────────

export const listComplaints = (
  status?: ComplaintStatus,
  severity?: SeverityLevel,
  page = 1,
  page_size = 50,
) =>
  client.get<Complaint[]>('/admin/complaints', {
    params: { status, severity, page, page_size },
  }).then((r) => r.data)

export const reassignComplaint = (complaintId: string, officer_id: string, reason?: string) =>
  client.post<Complaint>(`/admin/complaints/${complaintId}/reassign`, { officer_id, reason })
    .then((r) => r.data)

// ── Audit Logs ────────────────────────────────────────────────────────────────

export const listAuditLogs = (page = 1, page_size = 50, action?: string) =>
  client.get<AuditLog[]>('/admin/audit-logs', { params: { page, page_size, action } })
    .then((r) => r.data)

// ── Emergency Escalation ─────────────────────────────────────────────────────

export const escalateComplaint = (complaintId: string) =>
  client.post(`/admin/complaints/${complaintId}/escalate`).then((r) => r.data)

// ── Budget Dashboard ──────────────────────────────────────────────────────────

export const getBudget = () =>
  client.get<any>('/admin/budget').then((r) => r.data)

// ── Priority Queue ────────────────────────────────────────────────────────────

export const getPriorityQueue = (limit = 50) =>
  client.get<any[]>('/admin/complaints/priority-queue', { params: { limit } })
    .then((r) => r.data)

// ── Heatmap ───────────────────────────────────────────────────────────────────

export const getHeatmap = () =>
  client.get<{ points: HeatmapPoint[]; total: number }>('/complaints/map/heatmap')
    .then((r) => r.data)
