// Domain types for Rigel groupware modules (v3.1)
// Design doc: docs/02-design/features/그룹웨어-v3.1-확장.design.md §7

// ─── Board ──────────────────────────────────────
export type BoardType = 'general' | 'department';

export interface Board {
  id: string;
  tenant_id: string;
  name: string;
  description: string | null;
  board_type: BoardType;
  department_id: string | null;
  department_name?: string;
  is_active: boolean;
  sort_order: number;
  created_by: string;
  created_at: string;
}

export interface BoardPost {
  id: string;
  board_id: string;
  tenant_id: string;
  title: string;
  content: Record<string, unknown>;
  author_id: string;
  author_name?: string;
  is_pinned: boolean;
  view_count: number;
  comment_count?: number;
  created_at: string;
  updated_at: string;
}

export interface BoardComment {
  id: string;
  post_id: string;
  tenant_id: string;
  author_id: string;
  author_name?: string;
  content: string;
  created_at: string;
}

// ─── Announcement ───────────────────────────────
export interface Announcement {
  id: string;
  tenant_id: string;
  title: string;
  content: Record<string, unknown>;
  author_id: string;
  author_name?: string;
  is_popup: boolean;
  require_read_confirm: boolean;
  published_at: string | null;
  expires_at: string | null;
  is_read?: boolean;
  read_count?: number;
  total_count?: number;
  created_at: string;
  updated_at: string;
}

// ─── Calendar ───────────────────────────────────
export type EventType = 'personal' | 'department' | 'company';

export interface CalendarEvent {
  id: string;
  tenant_id: string;
  title: string;
  description: string | null;
  start_at: string;
  end_at: string;
  all_day: boolean;
  event_type: EventType;
  department_id: string | null;
  created_by: string;
  creator_name?: string;
  color: string | null;
  recurrence_rule: string | null;
}

export interface MeetingRoom {
  id: string;
  tenant_id: string;
  name: string;
  location: string | null;
  capacity: number | null;
  is_active: boolean;
}

export interface RoomReservation {
  id: string;
  room_id: string;
  tenant_id: string;
  title: string;
  reserved_by: string;
  reserved_by_name?: string;
  start_at: string;
  end_at: string;
  created_at: string;
}

// ─── Attendance ─────────────────────────────────
export type WorkType = 'normal' | 'late' | 'half_day' | 'annual_leave' | 'business_trip' | 'remote';

export const WORK_TYPE_LABELS: Record<WorkType, string> = {
  normal: '정상',
  late: '지각',
  half_day: '반차',
  annual_leave: '연차',
  business_trip: '출장',
  remote: '재택'
};

export interface AttendanceRecord {
  id: string;
  tenant_id: string;
  user_id: string;
  user_name?: string;
  work_date: string;
  clock_in: string | null;
  clock_out: string | null;
  work_type: WorkType;
  note: string | null;
}

export interface AttendanceSettings {
  tenant_id: string;
  work_start_time: string;
  work_end_time: string;
  late_threshold_minutes: number;
}

// ─── Employee Profile ───────────────────────────
export interface EmployeeProfile {
  user_id: string;
  tenant_id: string;
  employee_number: string | null;
  hire_date: string | null;
  phone_office: string | null;
  phone_mobile: string | null;
  job_title: string | null;
  job_position: string | null;
  bio: string | null;
}
