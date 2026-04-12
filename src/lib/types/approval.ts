// Domain types for Rigel approval system (v1.0)
// Design doc: docs/02-design/features/approval-mvp.design.md §1.2

// ─── Tenancy ──────────────────────────────────────
export type TenantRole = 'owner' | 'admin' | 'member';

export interface CurrentTenant {
  id: string;
  slug: string;
  name: string;
  role: TenantRole;
}

export interface TenantSummary {
  id: string;
  slug: string;
  name: string;
  role: TenantRole;
}

// ─── Form Schema ──────────────────────────────────
export type FormFieldType =
  | 'text'
  | 'textarea'
  | 'number'
  | 'date'
  | 'date-range'
  | 'select'
  | 'attachment';

export interface FormFieldBase {
  id: string;
  type: FormFieldType;
  label: string;
  required?: boolean;
  help?: string;
}

export interface TextField extends FormFieldBase {
  type: 'text' | 'textarea';
  placeholder?: string;
  maxLength?: number;
}

export interface NumberField extends FormFieldBase {
  type: 'number';
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
}

export interface DateField extends FormFieldBase {
  type: 'date';
  min?: string;
  max?: string;
}

export interface DateRangeField extends FormFieldBase {
  type: 'date-range';
  min?: string;
  max?: string;
}

export interface SelectField extends FormFieldBase {
  type: 'select';
  options: { value: string; label: string }[];
  multiple?: boolean;
}

export interface AttachmentField extends FormFieldBase {
  type: 'attachment';
  maxFiles?: number;
  maxSizeBytes?: number;
  accept?: string;
}

export type FormField =
  | TextField
  | NumberField
  | DateField
  | DateRangeField
  | SelectField
  | AttachmentField;

export interface FormSchema {
  version: 1;
  fields: FormField[];
}

// ─── Approval Line ────────────────────────────────
export type StepType = 'approval' | 'reference';

export interface ApprovalLineItem {
  userId: string;
  stepType: StepType;
}

// ─── Documents ────────────────────────────────────
export type DocumentStatus =
  | 'draft'
  | 'in_progress'
  | 'pending_post_facto' // v1.1 M13: 후결 진행 중
  | 'completed'
  | 'rejected'
  | 'withdrawn';

export type StepStatus = 'pending' | 'approved' | 'rejected' | 'skipped';

export interface ApprovalDocument {
  id: string;
  tenantId: string;
  docNumber: string;
  formId: string;
  formSchemaSnapshot: FormSchema;
  content: Record<string, unknown>;
  drafterId: string;
  status: DocumentStatus;
  currentStepIndex: number;
  submittedAt: string | null;
  completedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface ApprovalStep {
  id: string;
  tenantId: string;
  documentId: string;
  stepIndex: number;
  stepType: StepType;
  approverUserId: string;
  status: StepStatus;
  actedAt: string | null;
  comment: string | null;
  // v1.1 M12: 대리 수행자 (NULL = 본인 직접 승인)
  actedByProxyUserId: string | null;
}

export interface ApprovalAttachment {
  id: string;
  tenantId: string;
  documentId: string | null;
  storagePath: string;
  fileName: string;
  mime: string;
  size: number;
  uploadedBy: string;
  uploadedAt: string;
}

export type AuditAction =
  | 'draft_saved'
  | 'submit'
  | 'approve'
  | 'reject'
  | 'withdraw'
  | 'comment'
  // v1.1 M11~M14 확장
  | 'delegated' // M11: 전결 규칙 매칭으로 step 자동 skip
  | 'approved_by_proxy' // M12: 부재 대리인이 승인
  | 'submitted_post_facto' // M13: 후결 상신
  | 'auto_delegated'; // M14: 부재 등록 시 trigger/cron이 pending step 재배정

export interface ApprovalAuditLog {
  id: string;
  tenantId: string;
  documentId: string;
  actorId: string;
  action: AuditAction;
  payload: Record<string, unknown>;
  createdAt: string;
  // v1.1 M12: 대리 수행자 (NULL = 본인 직접 수행)
  actedByProxyUserId: string | null;
}

// ─── Org ──────────────────────────────────────────
export interface Department {
  id: string;
  tenantId: string;
  parentId: string | null;
  name: string;
  path: string;
  sortOrder: number;
}

export interface ProfileLite {
  id: string;
  displayName: string;
  email: string;
  departmentId: string | null;
  jobTitle: string | null;
}

// ─── Inbox ────────────────────────────────────────
export type InboxTab =
  | 'pending'
  | 'in_progress'
  | 'completed'
  | 'rejected'
  | 'drafts';

export interface InboxCounts {
  pending: number;
  in_progress: number;
  completed: number;
  rejected: number;
  drafts: number;
}
