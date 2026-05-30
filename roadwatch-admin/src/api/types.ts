export type UserRole = 'citizen' | 'officer' | 'admin'
export type DamageType = 'pothole' | 'crack' | 'waterlogging' | 'damaged_road' | 'other'
export type SeverityLevel = 'low' | 'medium' | 'high'
export type ComplaintStatus = 'pending' | 'assigned' | 'in_progress' | 'resolved' | 'rejected' | 'duplicate'
export type RepairStatus = 'pending' | 'in_progress' | 'completed' | 'failed'

export interface User {
  id: string
  phone_number: string
  name: string
  role: UserRole
  trust_score: number
  is_suspended: boolean
  suspension_reason?: string | null
  avatar_url: string | null
  created_at: string
}

export interface Officer {
  id: string
  user_id: string
  employee_id: string | null
  department: string | null
  ward_number: string | null
  area_name: string | null
  zone: string | null
  jurisdiction_geojson: object | null
  workload_count: number
  user: User
}

export interface Complaint {
  id: string
  citizen_id: string
  location_lat: number
  location_lng: number
  location_address: string | null
  image_url: string
  video_url: string | null
  description: string | null
  damage_type: DamageType | null
  severity: SeverityLevel | null
  ai_confidence_score: number | null
  ai_risk_score: number | null
  status: ComplaintStatus
  assigned_officer_id: string | null
  is_duplicate: boolean
  duplicate_of: string | null
  verified_confidence_score: number | null
  confirmation_count: number
  rejection_count: number
  resolution_notes: string | null
  created_at: string
  updated_at: string
}

export interface AdminStats {
  total_complaints: number
  pending_complaints: number
  resolved_complaints: number
  total_citizens: number
  total_officers: number
  high_severity_open: number
  avg_resolution_hours: number | null
}

export interface AuditLog {
  id: string
  actor_id: string | null
  action: string
  target_type: string | null
  target_id: string | null
  metadata: Record<string, unknown> | null
  ip_address: string | null
  created_at: string
}

export interface HeatmapPoint {
  lat: number
  lng: number
  weight: number
  complaint_id: string
  status: ComplaintStatus
}

export interface TokenResponse {
  access_token: string
  refresh_token: string
  token_type: string
  role: UserRole
  user_id: string
  name: string
}
