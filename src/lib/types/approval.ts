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

// ─── Form Schema v2 (조건부 필드, v2.0) ──────────────────
export interface ConditionalRule {
  if: {
    fieldId: string;
    operator: 'eq' | 'neq' | 'gte' | 'lte' | 'contains';
    value: unknown;
  };
  show?: string[];
  hide?: string[];
}

export interface FormSchema {
  version: 1;
  fields: FormField[];
  conditionals?: ConditionalRule[];  // v2.0: 조건부 필드
}

// ─── Approval Line ────────────────────────────────
export type StepType = 'approval' | 'agreement' | 'reference';

export interface ApprovalLineItem {
  userId: string;
  stepType: StepType;
  // v1.2: 병렬 그룹 pointer. undefined/미지정 시 순차 (step_index 기반 자동 할당).
  // 같은 groupOrder 를 가진 item 들은 병렬로 처리됨 (AND-only 완료 조건).
  groupOrder?: number;
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
  // v1.2 의미 재정의: "current group_order pointer". v1.0/v1.1 순차 문서는
  // group_order = step_index 이므로 기존 시맨틱과 값 동일.
  currentStepIndex: number;
  // v1.2: SHA-256(hex) of JCS-canonicalized payload. NULL for pre-v1.2 docs;
  // v1.2+ submissions RPC 가 NOT NULL 강제.
  contentHash: string | null;
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
  // v1.2 M15: 병렬 그룹 pointer. 동일 값 = 병렬, 증가 = 순차.
  // 기존 v1.0/v1.1 rows 는 group_order = step_index 로 backfill 됨.
  groupOrder: number;
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
  // v1.2: 클라이언트에서 crypto.subtle.digest('SHA-256') 로 계산. NULL for pre-v1.2 rows.
  sha256: string | null;
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
  | 'auto_delegated' // M14: 부재 등록 시 trigger/cron이 pending step 재배정
  | 'agreed'          // v2.2 M4: 합의 동의
  | 'disagreed';      // v2.2 M4: 합의 부동의

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
  // v1.2: 서명이미지 (Storage 경로 + 해시). 미등록 사용자는 둘 다 NULL.
  signatureStoragePath: string | null;
  signatureSha256: string | null;
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

// ─── Job Titles (v2.0) ───────────────────────────────────
export interface JobTitle {
  id: string;
  tenantId: string;
  name: string;
  level: number;
  createdAt: string;
}

// ─── Approval Rules (v2.0) ───────────────────────────────
export type RuleOperator = 'eq' | 'neq' | 'gte' | 'lte' | 'contains';

export interface RuleCondition {
  field: string;
  operator: RuleOperator;
  value: unknown;
}

export type LineRole = 'team_lead' | 'department_head' | 'ceo' | { userId: string };

export interface LineTemplateStep {
  role: LineRole;
  stepType: StepType;
  condition?: RuleCondition;
}

export interface ApprovalRule {
  id: string;
  tenantId: string;
  formId: string | null;
  name: string;
  conditionJson: RuleCondition | null;
  lineTemplateJson: LineTemplateStep[];
  priority: number;
  isActive: boolean;
}

// ─── Notifications (v1.3) ────────────────────────────────
export type NotificationType =
  | 'approval_requested'
  | 'approved'
  | 'rejected'
  | 'commented'
  | 'withdrawn';

export interface Notification {
  id: string;
  documentId: string;
  type: NotificationType;
  title: string;
  body: string | null;
  read: boolean;
  createdAt: string;
}
