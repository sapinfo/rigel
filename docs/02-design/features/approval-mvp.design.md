# Design — 전자결재 MVP v1.0 (approval-mvp)

> Feature: `approval-mvp`
> Phase: PDCA Design
> References: [Plan](../../01-plan/features/approval-mvp.plan.md), [Research](../../01-research/korean-groupware-approval-review.md)
> Stack: SvelteKit 2 + Svelte 5 runes + TypeScript + @supabase/ssr + Supabase local + Zod + Tailwind
> Date: 2026-04-11

---

## Executive Summary

| 항목 | 내용 |
|---|---|
| **목적** | Plan 문서의 섹션 7/8/9를 **실행 가능한 수준**으로 상세화. Do 단계에서 mechanical 구현이 가능하도록 모든 타입·DDL·RLS·RPC·컴포넌트 props·Zod 스키마 확정 |
| **Migration 수** | 13개 (Supabase local 적용) |
| **RPC 수** | 7개 plpgsql `SECURITY DEFINER` 함수 |
| **Svelte 컴포넌트** | 재사용 9개 + 페이지 15개 |
| **Zod 스키마** | 8개 (입력 경계 검증) |
| **라우트 수** | 15개 (login/signup/onboarding/invite + /t/[slug]/**) |
| **Storage 버킷** | 1개 (`approval-attachments`), 경로: `{tenant_id}/{YYYY-MM}/{upload_uuid}.{ext}` (월 버킷) |

### Value Delivered (4관점)

| 관점 | 내용 |
|---|---|
| **Problem** | Plan 문서의 고수준 설계만으로는 Do 단계에서 "이 컬럼은 무슨 타입?", "이 함수는 뭘 리턴?", "이 컴포넌트 props는?" 같은 결정을 매번 멈춰서 해야 함 |
| **Solution** | TypeScript 타입·SQL DDL·plpgsql 본문·Svelte 컴포넌트 props·Zod 스키마·Storage 정책·Seed 데이터 전부 확정. 애매함 0 |
| **Function UX Effect** | Do 단계에서 Design 문서 → 바로 파일 생성 → 빌드 통과. "설계를 다시 생각하는" 시간 제거 |
| **Core Value** | Design 문서가 곧 구현 계약서. 나중에 Gap Analysis에서 "Design 대비 구현이 벗어났는가" 판정 기준이 됨 |

---

## 1. TypeScript Types & Interfaces

### 1.1 `src/app.d.ts`

```typescript
import type { SupabaseClient, Session, User } from '@supabase/supabase-js';
import type { Database } from '$lib/types/database.types';
import type { CurrentTenant } from '$lib/types/approval';

declare global {
  namespace App {
    interface Locals {
      supabase: SupabaseClient<Database>;
      safeGetSession: () => Promise<{ session: Session | null; user: User | null }>;
      session: Session | null;
      user: User | null;
      currentTenant: CurrentTenant | null;
    }
    interface PageData {
      session: Session | null;
      currentTenant: CurrentTenant | null;
    }
    // interface Error {}
    // interface Platform {}
  }
}

export {};
```

### 1.2 `src/lib/types/approval.ts` — 도메인 타입

```typescript
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
  id: string;            // unique within form
  type: FormFieldType;
  label: string;
  required?: boolean;
  help?: string;         // hint text
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
  unit?: string;         // e.g. '원', '일'
}

export interface DateField extends FormFieldBase {
  type: 'date';
  min?: string;          // ISO date
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
  accept?: string;       // MIME glob
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
  userId: string;        // profiles.id
  stepType: StepType;
}

// ─── Documents ────────────────────────────────────
export type DocumentStatus =
  | 'draft'
  | 'in_progress'
  | 'completed'
  | 'rejected'
  | 'withdrawn';

export type StepStatus =
  | 'pending'
  | 'approved'
  | 'rejected'
  | 'skipped';

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
}

export interface ApprovalAttachment {
  id: string;
  tenantId: string;
  documentId: string | null;   // null when still pending
  storagePath: string;
  fileName: string;
  mime: string;
  size: number;
  uploadedBy: string;
  uploadedAt: string;
}

export interface ApprovalAuditLog {
  id: string;
  tenantId: string;
  documentId: string;
  actorId: string;
  action:
    | 'draft_saved'
    | 'submit'
    | 'approve'
    | 'reject'
    | 'withdraw'
    | 'comment';
  payload: Record<string, unknown>;
  createdAt: string;
}

// ─── Org ──────────────────────────────────────────
export interface Department {
  id: string;
  tenantId: string;
  parentId: string | null;
  name: string;
  path: string;          // materialized path, e.g. "/root/eng/platform"
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
  | 'pending'    // 내가 승인해야 할 것
  | 'in_progress'// 내가 기안, 아직 진행 중
  | 'completed'  // 내가 기안 or 결재 참여, 완료
  | 'rejected'   // 반려
  | 'drafts';    // 임시저장

export interface InboxCounts {
  pending: number;
  in_progress: number;
  completed: number;
  rejected: number;
  drafts: number;
}
```

### 1.3 `src/lib/types/database.types.ts`

`supabase gen types typescript --local > src/lib/types/database.types.ts` 명령으로 자동 생성.
Do 단계 M5(RLS+RPC 적용 직후)에 실행.

---

## 2. Database Migrations

> **Path convention**: `supabase/migrations/{sequence}_{name}.sql`
> **Naming**: 타임스탬프 대신 순차 번호 (MVP, 팀 1명)
> **Apply**: `supabase db reset --local` 또는 Supabase MCP `apply_migration`

### 2.0 RLS 작성 규칙 (M2에서 린터 경고로부터 도출)

M2 적용 후 Supabase database linter가 WARN 2종을 보고 → 정책 작성 표준 확정:

| 규칙 | 이유 | 예시 |
|---|---|---|
| **1. `auth.uid()`는 항상 `(SELECT auth.uid())`로 감싼다** | PostgreSQL이 row마다 함수 재평가하는 것을 막고 InitPlan으로 캐싱. advisor `auth_rls_initplan` 해결 | `USING (id = (SELECT auth.uid()))` |
| **2. `FOR ALL` 정책 금지** | SELECT를 포함해 다른 개별 SELECT 정책과 겹쳐 `multiple_permissive_policies` 유발. action별로 INSERT/UPDATE/DELETE 정책을 개별 생성 | `FOR INSERT ... WITH CHECK (is_tenant_admin(...))` + `FOR UPDATE ... USING + WITH CHECK` + `FOR DELETE ... USING` |
| **3. 중복 SELECT 정책 금지** | 같은 action에 permissive 정책 2개 이상이면 OR로 평가되어 느림. 하나의 정책에 OR로 합친다 | `USING (id = (SELECT auth.uid()) OR EXISTS (...))` |
| **4. helper 함수(`is_tenant_member`, `is_tenant_admin`)는 `SECURITY DEFINER` + `STABLE`** | RLS 재귀 방지 + 쿼리당 1회 평가 | 이미 0003에서 구현 |

아래 섹션 2.6~2.10(`approval_forms` 등)의 SQL은 설계 당시(M2 린터 확인 전) 작성되어 위 규칙을 100% 따르지 않는 부분이 있음. **M4/M5 구현 시 반드시 위 규칙으로 재작성**.

### 2.x Migration 순서 및 실제 M2 적용 결과

| # | 파일 | 상태 |
|---|---|---|
| 0001 | `0001_profiles.sql` | ✅ 적용 (M2) |
| 0002 | `0002_tenants.sql` | ✅ 적용 (M2) |
| 0003 | `0003_tenant_members.sql` | ✅ 적용 (M2, helper 함수 포함) |
| 0004 | `0004_tenant_invitations.sql` | ✅ 적용 (M2) |
| 0005 | `0005_departments.sql` | ✅ 적용 (M2) |
| 0006 | `0006_m2_linter_fixes.sql` | ✅ 적용 (M2, auth.uid wrap + FOR ALL 분해) |
| 0007 | `0007_m3_tenant_rpcs.sql` | ✅ 적용 (M3, fn_create_tenant / fn_copy_system_forms / fn_accept_invitation) |
| 0008 | `0008_approval_forms.sql` | ✅ 적용 (M4) |
| 0009 | `0009_approval_documents.sql` | ✅ 적용 (M4, ad_select은 0010에서 추가) |
| 0010 | `0010_approval_steps.sql` | ✅ 적용 (M4, document↔steps 순환 참조로 ad_select 여기서 추가) |
| 0011 | `0011_approval_attachments.sql` | ✅ 적용 (M4, Storage 버킷 + 3 정책 포함) |
| 0012 | `0012_approval_audit_logs.sql` | ✅ 적용 (M4, append-only) |
| 0013 | `0013_doc_numbers.sql` | ✅ 적용 (M4, fn_next_doc_number) |
| 0014 | `0014_seed_system_forms.sql` | ✅ 적용 (M4, 5 system forms) |
| 0015 | `0015_m4_linter_fixes.sql` | ✅ 적용 (M4, doc_number_sequences deny-all + approval_forms SELECT 통합) |
| 0016 | `0016_approval_rpcs.sql` | ✅ 적용 (M5) — fn_save_draft / fn_submit_draft / fn_approve_step(+Risk#13) / fn_reject_step / fn_withdraw_document / fn_add_comment |
| 0017 | `0017_m5_rls_recursion_fix.sql` | ✅ 적용 (M5) — ad_select ↔ as_select 정책 간 **RLS 무한 재귀** 발견, SECURITY DEFINER helper (`is_document_drafter`, `is_document_approver`, `get_document_tenant`) 도입으로 우회 |
| 0018~ | UI 연결 | M6+ |

M2 검증 결과:
- 6개 테이블 RLS 모두 enabled
- security advisor: **0건**
- performance advisor: WARN **0건** (INFO만 남음 — row 0이라 `unused_index`, 저빈도 FK)
- helper functions 호출 정상 (`is_tenant_member`, `is_tenant_admin` 모두 `false` 반환 — 비멤버 컨텍스트)
- `on_auth_user_created` trigger 정상 등록
- 정책 총 15개 (action별 분리됨)

### 2.1 `0001_profiles.sql`

```sql
-- 0001_profiles.sql
-- 사용자 글로벌 프로필. auth.users 확장.
CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  email text NOT NULL,
  default_tenant_id uuid,     -- ref tenants(id), FK는 0002 이후 추가
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX profiles_email_idx ON public.profiles (email);

-- Trigger: auth.users 삽입 시 profiles 자동 생성
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, display_name, email)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'display_name', split_part(NEW.email, '@', 1)),
    NEW.email
  );
  RETURN NEW;
END;
$$;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- 본인은 읽기/수정 가능
CREATE POLICY profiles_self_select ON public.profiles
  FOR SELECT TO authenticated
  USING (id = auth.uid());

CREATE POLICY profiles_self_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = auth.uid());

-- 같은 테넌트 멤버는 서로의 프로필을 읽을 수 있다 (조직도/결재선 표시 목적)
-- 주의: tenant_members 정의 이후(0003) 이 정책 추가
```

### 2.2 `0002_tenants.sql`

```sql
-- 0002_tenants.sql
CREATE TABLE public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL CHECK (
    slug ~ '^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$'
  ),
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  plan text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'enterprise')),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX tenants_owner_idx ON public.tenants (owner_id);

-- profiles.default_tenant_id FK 역참조 추가
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_default_tenant_fk
  FOREIGN KEY (default_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- tenants.select 정책은 0003 tenant_members 정의 후에 추가
```

### 2.3 `0003_tenant_members.sql`

```sql
-- 0003_tenant_members.sql
CREATE TYPE public.tenant_role AS ENUM ('owner', 'admin', 'member');

CREATE TABLE public.tenant_members (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role public.tenant_role NOT NULL,
  job_title text,
  department_id uuid,   -- FK는 0005에서 추가
  joined_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, user_id)
);

CREATE INDEX tenant_members_user_idx ON public.tenant_members (user_id);
CREATE INDEX tenant_members_tenant_idx ON public.tenant_members (tenant_id);

ALTER TABLE public.tenant_members ENABLE ROW LEVEL SECURITY;

-- Helper function: 현재 사용자가 특정 테넌트의 멤버인지
CREATE OR REPLACE FUNCTION public.is_tenant_member(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.tenant_members
    WHERE tenant_id = p_tenant_id AND user_id = auth.uid()
  );
$$;

-- Helper function: 현재 사용자가 특정 테넌트에서 admin 이상 역할인지
CREATE OR REPLACE FUNCTION public.is_tenant_admin(p_tenant_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.tenant_members
    WHERE tenant_id = p_tenant_id
      AND user_id = auth.uid()
      AND role IN ('owner', 'admin')
  );
$$;

-- tenants RLS 정책 (이제 is_tenant_member 사용 가능)
CREATE POLICY tenants_member_select ON public.tenants
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(id));

-- tenant_members 정책
CREATE POLICY tm_member_select ON public.tenant_members
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

-- profiles: 같은 테넌트 멤버는 서로 프로필 조회 가능
CREATE POLICY profiles_tenant_peer_select ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = auth.uid() OR
    EXISTS (
      SELECT 1 FROM public.tenant_members m1
      JOIN public.tenant_members m2 ON m1.tenant_id = m2.tenant_id
      WHERE m1.user_id = auth.uid()
        AND m2.user_id = public.profiles.id
    )
  );
```

### 2.4 `0004_tenant_invitations.sql`

```sql
-- 0004_tenant_invitations.sql
CREATE TABLE public.tenant_invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  email text NOT NULL,
  role public.tenant_role NOT NULL DEFAULT 'member',
  token uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  invited_by uuid NOT NULL REFERENCES auth.users(id),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '7 days'),
  accepted_at timestamptz,
  accepted_by uuid REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX tenant_invitations_token_idx ON public.tenant_invitations (token);
CREATE INDEX tenant_invitations_tenant_idx ON public.tenant_invitations (tenant_id);

ALTER TABLE public.tenant_invitations ENABLE ROW LEVEL SECURITY;

-- 관리자만 초대 관리
CREATE POLICY inv_admin_select ON public.tenant_invitations
  FOR SELECT TO authenticated
  USING (public.is_tenant_admin(tenant_id));

CREATE POLICY inv_admin_insert ON public.tenant_invitations
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY inv_admin_delete ON public.tenant_invitations
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));

-- 초대 수락은 RPC(fn_accept_invitation)에서 SECURITY DEFINER로 처리
-- (비멤버도 token만 맞으면 수락 가능해야 하므로 일반 RLS로는 어려움)
```

### 2.5 `0005_departments.sql`

```sql
-- 0005_departments.sql
CREATE TABLE public.departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES public.departments(id) ON DELETE CASCADE,
  name text NOT NULL,
  path text NOT NULL,          -- materialized path, e.g. "/hq/eng/platform"
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX departments_tenant_idx ON public.departments (tenant_id);
CREATE INDEX departments_parent_idx ON public.departments (parent_id);

-- user_departments는 선택적 (tenant_members에 department_id 기본 컬럼이 있음)
-- 겸직을 위해 별도 테이블로 분리
CREATE TABLE public.user_departments (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  is_primary boolean NOT NULL DEFAULT false,
  PRIMARY KEY (tenant_id, user_id, department_id)
);

-- tenant_members.department_id FK (primary dept의 편의)
ALTER TABLE public.tenant_members
  ADD CONSTRAINT tm_department_fk
  FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_departments ENABLE ROW LEVEL SECURITY;

CREATE POLICY dept_member_select ON public.departments
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY dept_admin_write ON public.departments
  FOR ALL TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY ud_member_select ON public.user_departments
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY ud_admin_write ON public.user_departments
  FOR ALL TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));
```

### 2.6 `0006_approval_forms.sql`

```sql
-- 0006_approval_forms.sql
CREATE TABLE public.approval_forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES public.tenants(id) ON DELETE CASCADE,  -- NULL이면 시스템 양식
  code text NOT NULL,                                              -- e.g. 'leave-request'
  name text NOT NULL,
  description text,
  schema jsonb NOT NULL,                                           -- FormSchema
  default_approval_line jsonb NOT NULL DEFAULT '[]'::jsonb,        -- ApprovalLineItem[]
  version int NOT NULL DEFAULT 1,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);

-- 시스템 양식은 tenant_id IS NULL, 고객사별 복사본과 분리
CREATE INDEX approval_forms_tenant_idx ON public.approval_forms (tenant_id);
CREATE INDEX approval_forms_system_idx ON public.approval_forms (tenant_id) WHERE tenant_id IS NULL;

ALTER TABLE public.approval_forms ENABLE ROW LEVEL SECURITY;

-- 시스템 양식은 인증된 모든 사용자가 조회 가능 (복사 참조용)
CREATE POLICY af_system_select ON public.approval_forms
  FOR SELECT TO authenticated
  USING (tenant_id IS NULL);

-- 테넌트 양식: 멤버 조회, 관리자 쓰기
CREATE POLICY af_tenant_select ON public.approval_forms
  FOR SELECT TO authenticated
  USING (tenant_id IS NOT NULL AND public.is_tenant_member(tenant_id));

CREATE POLICY af_tenant_admin_write ON public.approval_forms
  FOR ALL TO authenticated
  USING (tenant_id IS NOT NULL AND public.is_tenant_admin(tenant_id))
  WITH CHECK (tenant_id IS NOT NULL AND public.is_tenant_admin(tenant_id));
```

### 2.7 `0007_approval_documents.sql`

```sql
-- 0007_approval_documents.sql
CREATE TYPE public.document_status AS ENUM (
  'draft', 'in_progress', 'completed', 'rejected', 'withdrawn'
);

CREATE TABLE public.approval_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  doc_number text NOT NULL,
  form_id uuid NOT NULL REFERENCES public.approval_forms(id) ON DELETE RESTRICT,
  form_schema_snapshot jsonb NOT NULL,  -- FormSchema at submission time
  content jsonb NOT NULL DEFAULT '{}'::jsonb,  -- user input keyed by field.id
  drafter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  status public.document_status NOT NULL DEFAULT 'draft',
  current_step_index int NOT NULL DEFAULT 0,
  submitted_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, doc_number)
);

CREATE INDEX ad_tenant_idx ON public.approval_documents (tenant_id);
CREATE INDEX ad_drafter_idx ON public.approval_documents (tenant_id, drafter_id);
CREATE INDEX ad_status_idx ON public.approval_documents (tenant_id, status);

ALTER TABLE public.approval_documents ENABLE ROW LEVEL SECURITY;

-- 읽기: 같은 테넌트 멤버 AND (기안자 OR 결재선 참여자 OR 관리자)
CREATE POLICY ad_select ON public.approval_documents
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      drafter_id = auth.uid()
      OR public.is_tenant_admin(tenant_id)
      OR EXISTS (
        SELECT 1 FROM public.approval_steps s
        WHERE s.document_id = public.approval_documents.id
          AND s.approver_user_id = auth.uid()
      )
    )
  );

-- INSERT/UPDATE는 RPC 경유. 백업 정책만 등록.
CREATE POLICY ad_drafter_draft_update ON public.approval_documents
  FOR UPDATE TO authenticated
  USING (
    drafter_id = auth.uid()
    AND status = 'draft'
    AND public.is_tenant_member(tenant_id)
  );

-- INSERT 정책: RPC에서만 허용 (SECURITY DEFINER 우회)
-- 일반 경로는 차단
CREATE POLICY ad_no_direct_insert ON public.approval_documents
  FOR INSERT TO authenticated
  WITH CHECK (false);
```

### 2.8 `0008_approval_steps.sql`

```sql
-- 0008_approval_steps.sql
CREATE TYPE public.step_type AS ENUM ('approval', 'reference');
CREATE TYPE public.step_status AS ENUM ('pending', 'approved', 'rejected', 'skipped');

CREATE TABLE public.approval_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES public.approval_documents(id) ON DELETE CASCADE,
  step_index int NOT NULL,
  step_type public.step_type NOT NULL,
  approver_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  status public.step_status NOT NULL DEFAULT 'pending',
  acted_at timestamptz,
  comment text,
  UNIQUE (document_id, step_index)
);

CREATE INDEX as_tenant_idx ON public.approval_steps (tenant_id);
CREATE INDEX as_document_idx ON public.approval_steps (document_id);
CREATE INDEX as_approver_pending_idx
  ON public.approval_steps (tenant_id, approver_user_id)
  WHERE status = 'pending';

ALTER TABLE public.approval_steps ENABLE ROW LEVEL SECURITY;

-- 읽기: 문서 읽기 가능하면 step도 읽기 가능 (JOIN으로 체크)
CREATE POLICY as_select ON public.approval_steps
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.approval_documents d
      WHERE d.id = public.approval_steps.document_id
        -- ad_select와 동일 조건 반복
        AND public.is_tenant_member(d.tenant_id)
        AND (
          d.drafter_id = auth.uid()
          OR public.is_tenant_admin(d.tenant_id)
          OR public.approval_steps.approver_user_id = auth.uid()
          OR EXISTS (
            SELECT 1 FROM public.approval_steps s2
            WHERE s2.document_id = d.id AND s2.approver_user_id = auth.uid()
          )
        )
    )
  );

-- INSERT/UPDATE는 RPC 경유
CREATE POLICY as_no_direct_insert ON public.approval_steps
  FOR INSERT TO authenticated
  WITH CHECK (false);
```

### 2.9 `0009_approval_attachments.sql`

```sql
-- 0009_approval_attachments.sql
CREATE TABLE public.approval_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  document_id uuid REFERENCES public.approval_documents(id) ON DELETE CASCADE,
  storage_path text NOT NULL,   -- e.g. {tenant_id}/2026-04/{upload_uuid}.pdf
  file_name text NOT NULL,
  mime text NOT NULL,
  size bigint NOT NULL CHECK (size >= 0 AND size <= 52428800),   -- 50MB
  uploaded_by uuid NOT NULL REFERENCES auth.users(id),
  uploaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX att_tenant_idx ON public.approval_attachments (tenant_id);
CREATE INDEX att_document_idx ON public.approval_attachments (document_id);

ALTER TABLE public.approval_attachments ENABLE ROW LEVEL SECURITY;

-- 읽기: 업로드자 본인 또는 문서 읽기 가능한 사용자
CREATE POLICY att_select ON public.approval_attachments
  FOR SELECT TO authenticated
  USING (
    uploaded_by = auth.uid()
    OR (
      document_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.approval_documents d
        WHERE d.id = public.approval_attachments.document_id
          AND public.is_tenant_member(d.tenant_id)
          AND (
            d.drafter_id = auth.uid()
            OR public.is_tenant_admin(d.tenant_id)
            OR EXISTS (
              SELECT 1 FROM public.approval_steps s
              WHERE s.document_id = d.id AND s.approver_user_id = auth.uid()
            )
          )
      )
    )
  );

-- 업로드자가 직접 INSERT (pending 단계, document_id IS NULL)
CREATE POLICY att_own_insert ON public.approval_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = auth.uid()
    AND public.is_tenant_member(tenant_id)
    AND document_id IS NULL   -- 상신 전에는 document_id 없음
  );

-- 업로드자가 pending 단계에서 본인 것만 삭제 가능
CREATE POLICY att_own_delete ON public.approval_attachments
  FOR DELETE TO authenticated
  USING (
    uploaded_by = auth.uid()
    AND document_id IS NULL
  );

-- document_id 업데이트(pending→확정)는 RPC(fn_submit_draft)에서
```

### 2.10 `0010_approval_audit_logs.sql`

```sql
-- 0010_approval_audit_logs.sql
CREATE TYPE public.audit_action AS ENUM (
  'draft_saved', 'submit', 'approve', 'reject', 'withdraw', 'comment'
);

CREATE TABLE public.approval_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES public.approval_documents(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id),
  action public.audit_action NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX aal_document_idx ON public.approval_audit_logs (document_id, created_at);
CREATE INDEX aal_tenant_idx ON public.approval_audit_logs (tenant_id);

ALTER TABLE public.approval_audit_logs ENABLE ROW LEVEL SECURITY;

-- 읽기: 문서 읽을 수 있으면 감사 로그도 읽을 수 있음
CREATE POLICY aal_select ON public.approval_audit_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.approval_documents d
      WHERE d.id = public.approval_audit_logs.document_id
        AND public.is_tenant_member(d.tenant_id)
        AND (
          d.drafter_id = auth.uid()
          OR public.is_tenant_admin(d.tenant_id)
          OR EXISTS (
            SELECT 1 FROM public.approval_steps s
            WHERE s.document_id = d.id AND s.approver_user_id = auth.uid()
          )
        )
    )
  );

-- INSERT는 RPC에서만 (append-only)
CREATE POLICY aal_no_direct_insert ON public.approval_audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (false);

-- UPDATE/DELETE 전면 금지 (append-only)
-- PostgreSQL은 정책 없으면 FOR ALL 기본 거부
```

### 2.11 `0011_doc_numbers.sql`

```sql
-- 0011_doc_numbers.sql
-- 테넌트별 문서 번호 시퀀스
CREATE TABLE public.doc_number_sequences (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  day date NOT NULL,
  last_seq int NOT NULL DEFAULT 0,
  PRIMARY KEY (tenant_id, day)
);

CREATE OR REPLACE FUNCTION public.fn_next_doc_number(p_tenant_id uuid)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_day date := (now() AT TIME ZONE 'Asia/Seoul')::date;
  v_seq int;
BEGIN
  INSERT INTO public.doc_number_sequences (tenant_id, day, last_seq)
  VALUES (p_tenant_id, v_day, 1)
  ON CONFLICT (tenant_id, day)
  DO UPDATE SET last_seq = public.doc_number_sequences.last_seq + 1
  RETURNING last_seq INTO v_seq;

  RETURN 'APP-' || to_char(v_day, 'YYYYMMDD') || '-' || lpad(v_seq::text, 4, '0');
END;
$$;

-- RLS 불필요 (함수 내부에서만 사용)
ALTER TABLE public.doc_number_sequences ENABLE ROW LEVEL SECURITY;
-- 어떤 정책도 추가하지 않음 → 직접 접근 전면 차단
```

### 2.12 `0012_functions.sql`

모든 결재 mutation은 여기 정의된 `SECURITY DEFINER` 함수를 통해서만 수행됩니다.

```sql
-- 0012_functions.sql

-- ─── Tenant management ────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_create_tenant(
  p_slug text,
  p_name text
)
RETURNS public.tenants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant public.tenants;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.tenants (slug, name, owner_id)
  VALUES (p_slug, p_name, v_user_id)
  RETURNING * INTO v_tenant;

  INSERT INTO public.tenant_members (tenant_id, user_id, role)
  VALUES (v_tenant.id, v_user_id, 'owner');

  PERFORM public.fn_copy_system_forms(v_tenant.id);

  UPDATE public.profiles
  SET default_tenant_id = v_tenant.id, updated_at = now()
  WHERE id = v_user_id;

  RETURN v_tenant;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_tenant(text, text) TO authenticated;

-- ─── System form copy ─────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_copy_system_forms(p_tenant_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int;
BEGIN
  INSERT INTO public.approval_forms (
    tenant_id, code, name, description, schema, default_approval_line,
    version, is_published
  )
  SELECT
    p_tenant_id, code, name, description, schema, default_approval_line,
    1, true
  FROM public.approval_forms
  WHERE tenant_id IS NULL;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ─── Invitation acceptance ────────────────────────

CREATE OR REPLACE FUNCTION public.fn_accept_invitation(p_token uuid)
RETURNS public.tenants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_email text;
  v_inv public.tenant_invitations;
  v_tenant public.tenants;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;

  SELECT * INTO v_inv
  FROM public.tenant_invitations
  WHERE token = p_token
    AND expires_at > now()
    AND accepted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired invitation' USING ERRCODE = '22023';
  END IF;

  IF lower(v_inv.email) <> lower(v_email) THEN
    RAISE EXCEPTION 'Invitation email mismatch' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.tenant_members (tenant_id, user_id, role)
  VALUES (v_inv.tenant_id, v_user_id, v_inv.role)
  ON CONFLICT (tenant_id, user_id) DO NOTHING;

  UPDATE public.tenant_invitations
  SET accepted_at = now(), accepted_by = v_user_id
  WHERE id = v_inv.id;

  SELECT * INTO v_tenant FROM public.tenants WHERE id = v_inv.tenant_id;
  RETURN v_tenant;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_accept_invitation(uuid) TO authenticated;

-- ─── Draft management ─────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_save_draft(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_document_id uuid DEFAULT NULL
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  IF p_document_id IS NULL THEN
    INSERT INTO public.approval_documents (
      tenant_id, doc_number, form_id, form_schema_snapshot,
      content, drafter_id, status
    )
    SELECT
      p_tenant_id,
      'DRAFT-' || gen_random_uuid()::text,
      p_form_id,
      f.schema,
      p_content,
      v_user_id,
      'draft'
    FROM public.approval_forms f
    WHERE f.id = p_form_id
      AND (f.tenant_id = p_tenant_id OR f.tenant_id IS NULL)
    RETURNING * INTO v_doc;
  ELSE
    UPDATE public.approval_documents
    SET content = p_content, updated_at = now()
    WHERE id = p_document_id
      AND drafter_id = v_user_id
      AND status = 'draft'
    RETURNING * INTO v_doc;
  END IF;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Draft save failed' USING ERRCODE = '02000';
  END IF;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    p_tenant_id, v_doc.id, v_user_id, 'draft_saved', '{}'::jsonb
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_save_draft(uuid, uuid, jsonb, uuid) TO authenticated;

-- ─── Submit draft → in_progress ───────────────────

CREATE OR REPLACE FUNCTION public.fn_submit_draft(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_approval_line jsonb,          -- ApprovalLineItem[]
  p_attachment_ids uuid[] DEFAULT '{}'::uuid[],
  p_document_id uuid DEFAULT NULL -- 기존 draft를 상신 시
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
  v_schema jsonb;
  v_doc_number text;
  v_item jsonb;
  v_index int := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  IF jsonb_array_length(p_approval_line) = 0 THEN
    RAISE EXCEPTION 'Approval line must have at least one item' USING ERRCODE = '22023';
  END IF;

  SELECT schema INTO v_schema
  FROM public.approval_forms
  WHERE id = p_form_id
    AND is_published = true
    AND (tenant_id = p_tenant_id OR tenant_id IS NULL);

  IF v_schema IS NULL THEN
    RAISE EXCEPTION 'Form not found or unpublished' USING ERRCODE = '02000';
  END IF;

  v_doc_number := public.fn_next_doc_number(p_tenant_id);

  IF p_document_id IS NULL THEN
    INSERT INTO public.approval_documents (
      tenant_id, doc_number, form_id, form_schema_snapshot,
      content, drafter_id, status, current_step_index, submitted_at
    )
    VALUES (
      p_tenant_id, v_doc_number, p_form_id, v_schema,
      p_content, v_user_id, 'in_progress', 0, now()
    )
    RETURNING * INTO v_doc;
  ELSE
    UPDATE public.approval_documents
    SET doc_number = v_doc_number,
        form_schema_snapshot = v_schema,
        content = p_content,
        status = 'in_progress',
        current_step_index = 0,
        submitted_at = now(),
        updated_at = now()
    WHERE id = p_document_id
      AND drafter_id = v_user_id
      AND status = 'draft'
    RETURNING * INTO v_doc;

    IF v_doc.id IS NULL THEN
      RAISE EXCEPTION 'Draft not found or not owned' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 결재선 스냅샷 INSERT
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    INSERT INTO public.approval_steps (
      tenant_id, document_id, step_index, step_type,
      approver_user_id, status
    )
    VALUES (
      p_tenant_id, v_doc.id, v_index,
      (v_item->>'stepType')::public.step_type,
      (v_item->>'userId')::uuid,
      'pending'
    );
    v_index := v_index + 1;
  END LOOP;

  -- 첨부파일 document_id 확정
  IF array_length(p_attachment_ids, 1) > 0 THEN
    UPDATE public.approval_attachments
    SET document_id = v_doc.id
    WHERE id = ANY(p_attachment_ids)
      AND uploaded_by = v_user_id
      AND document_id IS NULL
      AND tenant_id = p_tenant_id;
  END IF;

  -- 감사 로그
  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    p_tenant_id, v_doc.id, v_user_id, 'submit',
    jsonb_build_object('approval_line', p_approval_line)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_draft(uuid, uuid, jsonb, jsonb, uuid[], uuid)
  TO authenticated;

-- ─── Approve current step ─────────────────────────

CREATE OR REPLACE FUNCTION public.fn_approve_step(
  p_document_id uuid,
  p_comment text DEFAULT NULL
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
  v_step public.approval_steps;
  v_next_step public.approval_steps;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_doc
  FROM public.approval_documents
  WHERE id = p_document_id
  FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found' USING ERRCODE = '02000';
  END IF;

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Document not in progress' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND step_index = v_doc.current_step_index
  FOR UPDATE;

  IF v_step.approver_user_id <> v_user_id THEN
    RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
  END IF;

  IF v_step.status <> 'pending' THEN
    RAISE EXCEPTION 'Step not pending' USING ERRCODE = '22023';
  END IF;

  IF v_step.step_type <> 'approval' THEN
    RAISE EXCEPTION 'Cannot approve a reference step' USING ERRCODE = '22023';
  END IF;

  UPDATE public.approval_steps
  SET status = 'approved', acted_at = now(), comment = p_comment
  WHERE id = v_step.id;

  -- 다음 approval step 찾기 (reference step은 건너뜀)
  SELECT * INTO v_next_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND step_index > v_doc.current_step_index
    AND step_type = 'approval'
  ORDER BY step_index ASC
  LIMIT 1;

  IF v_next_step.id IS NULL THEN
    -- 마지막 결재 단계였음 → 완료
    UPDATE public.approval_documents
    SET status = 'completed',
        completed_at = now(),
        updated_at = now()
    WHERE id = p_document_id
    RETURNING * INTO v_doc;
  ELSE
    UPDATE public.approval_documents
    SET current_step_index = v_next_step.step_index,
        updated_at = now()
    WHERE id = p_document_id
    RETURNING * INTO v_doc;
  END IF;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'approve',
    jsonb_build_object('step_index', v_step.step_index, 'comment', p_comment)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_approve_step(uuid, text) TO authenticated;

-- ─── Reject current step ──────────────────────────

CREATE OR REPLACE FUNCTION public.fn_reject_step(
  p_document_id uuid,
  p_comment text
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
  v_step public.approval_steps;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_comment IS NULL OR char_length(trim(p_comment)) = 0 THEN
    RAISE EXCEPTION 'Reject reason required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_doc FROM public.approval_documents
  WHERE id = p_document_id FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found' USING ERRCODE = '02000';
  END IF;

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Document not in progress' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_step FROM public.approval_steps
  WHERE document_id = p_document_id AND step_index = v_doc.current_step_index
  FOR UPDATE;

  IF v_step.approver_user_id <> v_user_id OR v_step.status <> 'pending' THEN
    RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
  END IF;

  UPDATE public.approval_steps
  SET status = 'rejected', acted_at = now(), comment = p_comment
  WHERE id = v_step.id;

  -- 이후 단계는 skipped
  UPDATE public.approval_steps
  SET status = 'skipped'
  WHERE document_id = p_document_id
    AND step_index > v_step.step_index
    AND status = 'pending';

  UPDATE public.approval_documents
  SET status = 'rejected', updated_at = now()
  WHERE id = p_document_id
  RETURNING * INTO v_doc;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'reject',
    jsonb_build_object('step_index', v_step.step_index, 'comment', p_comment)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_reject_step(uuid, text) TO authenticated;

-- ─── Withdraw document (drafter only, before completion) ──

CREATE OR REPLACE FUNCTION public.fn_withdraw_document(
  p_document_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_doc FROM public.approval_documents
  WHERE id = p_document_id FOR UPDATE;

  IF v_doc.drafter_id <> v_user_id THEN
    RAISE EXCEPTION 'Only drafter can withdraw' USING ERRCODE = '42501';
  END IF;

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Cannot withdraw this document' USING ERRCODE = '22023';
  END IF;

  -- pending 단계 모두 skipped
  UPDATE public.approval_steps
  SET status = 'skipped'
  WHERE document_id = p_document_id AND status = 'pending';

  UPDATE public.approval_documents
  SET status = 'withdrawn', updated_at = now()
  WHERE id = p_document_id
  RETURNING * INTO v_doc;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'withdraw',
    jsonb_build_object('reason', p_reason)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_withdraw_document(uuid, text) TO authenticated;

-- ─── Comment (any tenant member who can view the doc) ────

CREATE OR REPLACE FUNCTION public.fn_add_comment(
  p_document_id uuid,
  p_comment text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_comment IS NULL OR char_length(trim(p_comment)) = 0 THEN
    RAISE EXCEPTION 'Comment required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_doc FROM public.approval_documents WHERE id = p_document_id;

  IF v_doc.id IS NULL OR NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Document not accessible' USING ERRCODE = '42501';
  END IF;

  -- 접근권: drafter OR approver OR admin
  IF NOT (
    v_doc.drafter_id = v_user_id
    OR public.is_tenant_admin(v_doc.tenant_id)
    OR EXISTS (
      SELECT 1 FROM public.approval_steps s
      WHERE s.document_id = v_doc.id AND s.approver_user_id = v_user_id
    )
  ) THEN
    RAISE EXCEPTION 'No access to this document' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'comment',
    jsonb_build_object('comment', p_comment)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_add_comment(uuid, text) TO authenticated;
```

### 2.13 `0013_seed_system_forms.sql`

5종 시스템 양식. `tenant_id IS NULL`. 테넌트 생성 시 `fn_copy_system_forms`가 복사.

```sql
-- 0013_seed_system_forms.sql

INSERT INTO public.approval_forms (tenant_id, code, name, description, schema, default_approval_line, is_published)
VALUES
-- 1. 일반 기안서
(NULL, 'general', '일반 기안서', '일반적인 업무 기안',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "제목", "required": true, "placeholder": "기안 제목을 입력하세요", "maxLength": 200},
     {"id": "summary", "type": "textarea", "label": "요약", "required": true, "maxLength": 500},
     {"id": "body", "type": "textarea", "label": "내용", "required": true},
     {"id": "attachments", "type": "attachment", "label": "첨부파일", "maxFiles": 5, "maxSizeBytes": 10485760}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 2. 휴가신청서
(NULL, 'leave-request', '휴가신청서', '연차·반차·경조사 휴가 신청',
 '{
   "version": 1,
   "fields": [
     {"id": "leave_type", "type": "select", "label": "휴가 종류", "required": true,
      "options": [
        {"value": "annual", "label": "연차"},
        {"value": "half", "label": "반차"},
        {"value": "sick", "label": "병가"},
        {"value": "family", "label": "경조사"},
        {"value": "unpaid", "label": "무급휴가"}
      ]},
     {"id": "period", "type": "date-range", "label": "휴가 기간", "required": true},
     {"id": "reason", "type": "textarea", "label": "사유", "required": true, "maxLength": 500},
     {"id": "contact", "type": "text", "label": "비상 연락처", "required": false}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 3. 지출결의서
(NULL, 'expense-report', '지출결의서', '법인카드·경비 지출 정산',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "제목", "required": true, "maxLength": 200},
     {"id": "expense_date", "type": "date", "label": "지출일", "required": true},
     {"id": "amount", "type": "number", "label": "금액", "required": true, "min": 0, "unit": "원"},
     {"id": "category", "type": "select", "label": "비용 항목", "required": true,
      "options": [
        {"value": "meal", "label": "식대"},
        {"value": "transport", "label": "교통비"},
        {"value": "supplies", "label": "비품"},
        {"value": "entertainment", "label": "접대비"},
        {"value": "other", "label": "기타"}
      ]},
     {"id": "description", "type": "textarea", "label": "사용 내역", "required": true},
     {"id": "receipts", "type": "attachment", "label": "영수증", "required": true, "maxFiles": 10, "accept": "image/*,application/pdf"}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 4. 품의서
(NULL, 'proposal', '품의서', '지출 전 승인이 필요한 품의',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "품의 제목", "required": true, "maxLength": 200},
     {"id": "purpose", "type": "textarea", "label": "품의 목적", "required": true},
     {"id": "budget", "type": "number", "label": "예산", "required": true, "min": 0, "unit": "원"},
     {"id": "justification", "type": "textarea", "label": "타당성", "required": true},
     {"id": "attachments", "type": "attachment", "label": "근거 자료", "maxFiles": 10}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true),

-- 5. 업무협조전
(NULL, 'cooperation', '업무협조전', '타 부서에 업무 협조 요청',
 '{
   "version": 1,
   "fields": [
     {"id": "title", "type": "text", "label": "제목", "required": true, "maxLength": 200},
     {"id": "target_department", "type": "text", "label": "협조 요청 부서", "required": true},
     {"id": "deadline", "type": "date", "label": "요청 완료일"},
     {"id": "content", "type": "textarea", "label": "협조 요청 내용", "required": true},
     {"id": "attachments", "type": "attachment", "label": "첨부파일", "maxFiles": 5}
   ]
 }'::jsonb,
 '[]'::jsonb,
 true);
```

---

## 3. Supabase Storage

### 3.1 버킷 생성

```sql
-- supabase/storage.sql (또는 대시보드/MCP에서)
INSERT INTO storage.buckets (id, name, public)
VALUES ('approval-attachments', 'approval-attachments', false)
ON CONFLICT DO NOTHING;
```

### 3.2 Storage RLS Policies

```sql
-- 읽기: 파일 경로의 첫 세그먼트(tenant_id)로 멤버십 확인
CREATE POLICY att_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'approval-attachments'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT tenant_id FROM public.tenant_members WHERE user_id = auth.uid()
    )
  );

-- 업로드: 본인이 멤버인 테넌트의 경로에만
CREATE POLICY att_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'approval-attachments'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT tenant_id FROM public.tenant_members WHERE user_id = auth.uid()
    )
  );

-- 삭제: 본인이 업로드한 파일만 (approval_attachments row가 pending일 때만)
CREATE POLICY att_storage_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'approval-attachments'
    AND owner = auth.uid()
  );
```

### 3.3 경로 규칙 — 월 버킷 (flat files under YYYY-MM)

```
approval-attachments/
└── {tenant_id}/                    # RLS 첫 세그먼트
    ├── 2026-04/                    # 업로드 월 (Asia/Seoul)
    │   ├── b3f9a12c-...-d4e7.pdf   # upload_uuid.ext
    │   ├── 9a8b7c6d-...-ef12.jpg
    │   └── ...
    ├── 2026-05/
    │   └── ...
    └── 2026-06/
        └── ...
```

**설계 근거**:
- **파일당 폴더를 만들지 않음** — 파일이 `YYYY-MM/` 아래 직접 존재. 기안마다 폴더가 폭증하는 현상을 방지
- **월 prefix로 자연 파티셔닝** — 한 prefix당 일반적으로 수천 개 이하 유지 → `list()` 1페이지로 커버
- **아카이빙 친화** — retention 정책 적용 시 `2024-*` prefix 일괄 삭제 가능
- **RLS 무변경** — 첫 세그먼트(`tenant_id`)만 체크하므로 기존 정책 그대로 동작
- **원본 파일명은 DB에만** — `approval_attachments.file_name` 컬럼에 저장. Storage 경로에는 확장자만 유지하여 Studio 미리보기·MIME 추론 용도로만 사용
- **다운로드 시 원본 파일명 복원** — `createSignedUrl(path, ttl, { download: 'original.pdf' })`이 `Content-Disposition: attachment; filename="original.pdf"` 헤더를 설정하므로 브라우저는 DB에 저장된 원본 파일명으로 다운로드

**pending vs document 구분**:
- Storage 경로는 상신 전후 **동일** — 파일 이동 불필요 (Storage move는 COPY+DELETE라 원자성 보장 어렵고 비용 2배)
- DB의 `approval_attachments.document_id`가 `NULL`이면 pending, 값이 있으면 확정
- `fn_submit_draft`가 `document_id`만 UPDATE

**월 경계 엣지케이스**:
- 4월 30일 23:59:55에 업로드 중 자정 넘어감 → 업로드 시점의 `YYYY-MM`을 그대로 사용(재계산 X). 파일은 4월 prefix에 저장됨. 의도된 동작(업로드 시간 기준이지 상신 시간 기준 아님)

---

## 4. Frontend: Routing & Load/Action Signatures

### 4.1 `src/hooks.server.ts`

```typescript
import { createServerClient } from '@supabase/ssr';
import { type Handle, redirect } from '@sveltejs/kit';
import { sequence } from '@sveltejs/kit/hooks';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

const supabase: Handle = async ({ event, resolve }) => {
  event.locals.supabase = createServerClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll: () => event.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value, options }) => {
            event.cookies.set(name, value, { ...options, path: '/' });
          });
        }
      }
    }
  );

  event.locals.safeGetSession = async () => {
    const {
      data: { session }
    } = await event.locals.supabase.auth.getSession();
    if (!session) return { session: null, user: null };

    const {
      data: { user },
      error
    } = await event.locals.supabase.auth.getUser();
    if (error) return { session: null, user: null };

    return { session, user };
  };

  return resolve(event, {
    filterSerializedResponseHeaders: (name) =>
      name === 'content-range' || name === 'x-supabase-api-version'
  });
};

const PUBLIC_ROUTES = [
  '/',
  '/login',
  '/signup',
  '/invite'
];

const authGuard: Handle = async ({ event, resolve }) => {
  const { session, user } = await event.locals.safeGetSession();
  event.locals.session = session;
  event.locals.user = user;
  event.locals.currentTenant = null;

  const path = event.url.pathname;
  const isPublic = PUBLIC_ROUTES.some(
    (p) => path === p || path.startsWith(p + '/')
  );

  if (!isPublic && !user) {
    redirect(303, `/login?redirect=${encodeURIComponent(path)}`);
  }

  // 로그인했는데 /login, /signup 접근 시 리디렉트
  if ((path === '/login' || path === '/signup') && user) {
    redirect(303, '/');
  }

  return resolve(event);
};

export const handle: Handle = sequence(supabase, authGuard);
```

### 4.2 `src/routes/+layout.server.ts`

```typescript
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals }) => {
  if (!locals.user) {
    return { session: null, user: null, tenants: [] };
  }

  // 내가 소속된 테넌트 목록 (스위처 표시용)
  const { data: tenants } = await locals.supabase
    .from('tenant_members')
    .select('role, tenant:tenants(id, slug, name)')
    .eq('user_id', locals.user.id);

  return {
    session: locals.session,
    user: locals.user,
    tenants:
      tenants?.map((t) => ({
        id: t.tenant.id,
        slug: t.tenant.slug,
        name: t.tenant.name,
        role: t.role
      })) ?? []
  };
};
```

### 4.3 `src/routes/+page.server.ts` (entry redirect)

```typescript
import { redirect } from '@sveltejs/kit';
import type { PageServerLoad } from './$types';

export const load: PageServerLoad = async ({ locals, parent }) => {
  if (!locals.user) redirect(303, '/login');

  const { tenants } = await parent();

  if (tenants.length === 0) redirect(303, '/onboarding/create-tenant');

  // profiles.default_tenant_id가 있으면 그걸로, 아니면 첫 테넌트
  const { data: profile } = await locals.supabase
    .from('profiles')
    .select('default_tenant_id')
    .eq('id', locals.user.id)
    .single();

  const targetTenant =
    tenants.find((t) => t.id === profile?.default_tenant_id) ?? tenants[0];

  redirect(303, `/t/${targetTenant.slug}/approval/inbox`);
};
```

### 4.4 `src/routes/t/[tenantSlug]/+layout.server.ts`

```typescript
import { error } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ locals, params }) => {
  if (!locals.user) error(401, 'Not authenticated');

  const { data, error: err } = await locals.supabase
    .from('tenant_members')
    .select('role, tenant:tenants!inner(id, slug, name)')
    .eq('user_id', locals.user.id)
    .eq('tenant.slug', params.tenantSlug)
    .single();

  if (err || !data) error(404, 'Tenant not found or you are not a member');

  locals.currentTenant = {
    id: data.tenant.id,
    slug: data.tenant.slug,
    name: data.tenant.name,
    role: data.role
  };

  return { currentTenant: locals.currentTenant };
};
```

### 4.5 `src/routes/t/[tenantSlug]/admin/+layout.server.ts`

```typescript
import { error } from '@sveltejs/kit';
import type { LayoutServerLoad } from './$types';

export const load: LayoutServerLoad = async ({ parent }) => {
  const { currentTenant } = await parent();
  if (!currentTenant || !['owner', 'admin'].includes(currentTenant.role)) {
    error(403, 'Admin only');
  }
  return { currentTenant };
};
```

### 4.6 대표 Action/Load 시그니처

#### `/t/[slug]/approval/inbox/+page.server.ts`

```typescript
import type { PageServerLoad } from './$types';
import type { InboxTab, InboxCounts } from '$lib/types/approval';

export const load: PageServerLoad = async ({ locals, url, parent }) => {
  const { currentTenant } = await parent();
  const tab = (url.searchParams.get('tab') ?? 'pending') as InboxTab;

  const supabase = locals.supabase;
  const uid = locals.user!.id;
  const tid = currentTenant!.id;

  const listQuery = (() => {
    switch (tab) {
      case 'pending':
        // 내가 현재 단계 approver인 것들
        return supabase
          .from('approval_documents')
          .select(
            `id, doc_number, form_id, drafter:profiles!drafter_id(id, display_name),
             status, current_step_index, submitted_at,
             form:approval_forms(name),
             steps:approval_steps!inner(step_index, approver_user_id, status)`
          )
          .eq('tenant_id', tid)
          .eq('status', 'in_progress')
          .eq('steps.approver_user_id', uid)
          .eq('steps.status', 'pending');
      case 'in_progress':
        return supabase
          .from('approval_documents')
          .select('id, doc_number, status, submitted_at, form:approval_forms(name)')
          .eq('tenant_id', tid)
          .eq('drafter_id', uid)
          .eq('status', 'in_progress');
      case 'completed':
        return supabase
          .from('approval_documents')
          .select('id, doc_number, status, completed_at, form:approval_forms(name)')
          .eq('tenant_id', tid)
          .in('status', ['completed', 'withdrawn'])
          .order('completed_at', { ascending: false });
      case 'rejected':
        return supabase
          .from('approval_documents')
          .select('id, doc_number, status, updated_at, form:approval_forms(name)')
          .eq('tenant_id', tid)
          .eq('status', 'rejected');
      case 'drafts':
        return supabase
          .from('approval_documents')
          .select('id, form_id, updated_at, form:approval_forms(name)')
          .eq('tenant_id', tid)
          .eq('drafter_id', uid)
          .eq('status', 'draft');
    }
  })();

  const [{ data: documents }, counts] = await Promise.all([
    listQuery.limit(100),
    loadInboxCounts(supabase, tid, uid)
  ]);

  return { tab, documents: documents ?? [], counts };
};

async function loadInboxCounts(
  supabase: App.Locals['supabase'],
  tenantId: string,
  userId: string
): Promise<InboxCounts> {
  // RPC 또는 병렬 count 쿼리 5개. v1.0은 단순 count.
  const counts = await Promise.all([
    supabase
      .from('approval_steps')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('approver_user_id', userId)
      .eq('status', 'pending'),
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('drafter_id', userId)
      .eq('status', 'in_progress'),
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .in('status', ['completed', 'withdrawn']),
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('status', 'rejected'),
    supabase
      .from('approval_documents')
      .select('id', { count: 'exact', head: true })
      .eq('tenant_id', tenantId)
      .eq('drafter_id', userId)
      .eq('status', 'draft')
  ]);
  return {
    pending: counts[0].count ?? 0,
    in_progress: counts[1].count ?? 0,
    completed: counts[2].count ?? 0,
    rejected: counts[3].count ?? 0,
    drafts: counts[4].count ?? 0
  };
}
```

#### `/t/[slug]/approval/documents/[id]/+page.server.ts`

```typescript
import { error, fail, redirect } from '@sveltejs/kit';
import type { Actions, PageServerLoad } from './$types';
import { approveSchema, rejectSchema, commentSchema } from '$lib/server/schemas/approvalActions';

export const load: PageServerLoad = async ({ locals, params, parent }) => {
  const { currentTenant } = await parent();

  const { data: doc, error: err } = await locals.supabase
    .from('approval_documents')
    .select(
      `*, form:approval_forms(name, code),
       drafter:profiles!drafter_id(id, display_name, email),
       steps:approval_steps(*, approver:profiles!approver_user_id(id, display_name, email)),
       attachments:approval_attachments(*),
       audits:approval_audit_logs(*, actor:profiles!actor_id(id, display_name))`
    )
    .eq('id', params.id)
    .eq('tenant_id', currentTenant!.id)
    .single();

  if (err || !doc) error(404, 'Document not found');

  const uid = locals.user!.id;
  const currentStep = doc.steps
    .sort((a, b) => a.step_index - b.step_index)
    .find((s) => s.step_index === doc.current_step_index);

  const canApprove =
    doc.status === 'in_progress' &&
    currentStep?.approver_user_id === uid &&
    currentStep?.status === 'pending' &&
    currentStep?.step_type === 'approval';

  const canWithdraw = doc.status === 'in_progress' && doc.drafter_id === uid;

  return { document: doc, canApprove, canWithdraw };
};

export const actions: Actions = {
  approve: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const formData = await request.formData();
    const parsed = approveSchema.safeParse({
      comment: formData.get('comment') || null
    });
    if (!parsed.success) return fail(400, { error: parsed.error.flatten() });

    const { error: err } = await locals.supabase.rpc('fn_approve_step', {
      p_document_id: params.id,
      p_comment: parsed.data.comment
    });
    if (err) return fail(400, { error: err.message });

    return { success: true };
  },

  reject: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const formData = await request.formData();
    const parsed = rejectSchema.safeParse({
      comment: formData.get('comment')
    });
    if (!parsed.success) return fail(400, { error: parsed.error.flatten() });

    const { error: err } = await locals.supabase.rpc('fn_reject_step', {
      p_document_id: params.id,
      p_comment: parsed.data.comment
    });
    if (err) return fail(400, { error: err.message });

    return { success: true };
  },

  withdraw: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const formData = await request.formData();

    const { error: err } = await locals.supabase.rpc('fn_withdraw_document', {
      p_document_id: params.id,
      p_reason: formData.get('reason')?.toString() || null
    });
    if (err) return fail(400, { error: err.message });

    return { success: true };
  },

  comment: async ({ request, locals, params }) => {
    if (!locals.user) return fail(401);
    const formData = await request.formData();
    const parsed = commentSchema.safeParse({
      comment: formData.get('comment')
    });
    if (!parsed.success) return fail(400, { error: parsed.error.flatten() });

    const { error: err } = await locals.supabase.rpc('fn_add_comment', {
      p_document_id: params.id,
      p_comment: parsed.data.comment
    });
    if (err) return fail(400, { error: err.message });

    return { success: true };
  }
};
```

---

## 5. Zod Schemas

### 5.1 `src/lib/server/schemas/tenantActions.ts`

```typescript
import { z } from 'zod';

export const createTenantSchema = z.object({
  slug: z
    .string()
    .min(3)
    .max(32)
    .regex(/^[a-z0-9][a-z0-9-]*[a-z0-9]$/, '소문자·숫자·하이픈만 가능'),
  name: z.string().min(1).max(100)
});

export const inviteSchema = z.object({
  email: z.string().email(),
  role: z.enum(['admin', 'member']).default('member')
});
```

### 5.2 `src/lib/server/schemas/approvalActions.ts`

```typescript
import { z } from 'zod';

export const approvalLineItemSchema = z.object({
  userId: z.string().uuid(),
  stepType: z.enum(['approval', 'reference'])
});

export const approvalLineSchema = z
  .array(approvalLineItemSchema)
  .min(1, '결재선은 최소 1명 이상')
  .refine(
    (line) => line.some((i) => i.stepType === 'approval'),
    '승인 단계가 최소 1개 필요'
  )
  .refine((line) => {
    const userIds = line.map((i) => i.userId);
    return new Set(userIds).size === userIds.length;
  }, '결재자 중복 불가');

export const submitDraftSchema = z.object({
  formId: z.string().uuid(),
  content: z.record(z.string(), z.unknown()),
  approvalLine: approvalLineSchema,
  attachmentIds: z.array(z.string().uuid()).default([]),
  documentId: z.string().uuid().optional()
});

export const approveSchema = z.object({
  comment: z.string().trim().max(2000).nullable().optional()
});

export const rejectSchema = z.object({
  comment: z
    .string()
    .trim()
    .min(1, '반려 사유 필수')
    .max(2000)
});

export const commentSchema = z.object({
  comment: z.string().trim().min(1).max(2000)
});

export const withdrawSchema = z.object({
  reason: z.string().trim().max(2000).optional()
});
```

### 5.3 `src/lib/server/schemas/formSchema.ts`

```typescript
import { z } from 'zod';

const baseField = {
  id: z.string().regex(/^[a-z][a-z0-9_]*$/, '필드 ID는 snake_case'),
  label: z.string().min(1),
  required: z.boolean().optional(),
  help: z.string().optional()
};

const textField = z.object({
  ...baseField,
  type: z.enum(['text', 'textarea']),
  placeholder: z.string().optional(),
  maxLength: z.number().int().positive().optional()
});

const numberField = z.object({
  ...baseField,
  type: z.literal('number'),
  min: z.number().optional(),
  max: z.number().optional(),
  step: z.number().positive().optional(),
  unit: z.string().optional()
});

const dateField = z.object({
  ...baseField,
  type: z.literal('date'),
  min: z.string().optional(),
  max: z.string().optional()
});

const dateRangeField = z.object({
  ...baseField,
  type: z.literal('date-range'),
  min: z.string().optional(),
  max: z.string().optional()
});

const selectField = z.object({
  ...baseField,
  type: z.literal('select'),
  options: z
    .array(z.object({ value: z.string(), label: z.string() }))
    .min(1),
  multiple: z.boolean().optional()
});

const attachmentField = z.object({
  ...baseField,
  type: z.literal('attachment'),
  maxFiles: z.number().int().positive().max(20).optional(),
  maxSizeBytes: z.number().int().positive().optional(),
  accept: z.string().optional()
});

export const formFieldSchema = z.discriminatedUnion('type', [
  textField,
  numberField,
  dateField,
  dateRangeField,
  selectField,
  attachmentField
]);

export const formSchemaSchema = z.object({
  version: z.literal(1),
  fields: z
    .array(formFieldSchema)
    .min(1)
    .refine((fields) => {
      const ids = fields.map((f) => f.id);
      return new Set(ids).size === ids.length;
    }, '필드 ID 중복 불가')
});

export type ParsedFormSchema = z.infer<typeof formSchemaSchema>;
```

### 5.4 동적 입력 검증 — `validateContent`

```typescript
// src/lib/server/schemas/validateContent.ts
import { z, type ZodTypeAny } from 'zod';
import type { FormSchema, FormField } from '$lib/types/approval';

function fieldToZod(field: FormField): ZodTypeAny {
  let zod: ZodTypeAny;
  switch (field.type) {
    case 'text':
    case 'textarea':
      zod = field.maxLength
        ? z.string().max(field.maxLength)
        : z.string();
      break;
    case 'number':
      zod = z.coerce.number();
      if (field.min !== undefined) zod = (zod as z.ZodNumber).min(field.min);
      if (field.max !== undefined) zod = (zod as z.ZodNumber).max(field.max);
      break;
    case 'date':
    case 'date-range':
      zod = z.string();  // ISO 또는 {start,end}
      break;
    case 'select':
      zod = field.multiple
        ? z.array(z.string())
        : z.string();
      break;
    case 'attachment':
      zod = z.array(z.string().uuid());
      break;
  }
  return field.required ? zod : zod.optional().nullable();
}

export function buildContentSchema(schema: FormSchema) {
  const shape: Record<string, ZodTypeAny> = {};
  for (const field of schema.fields) {
    shape[field.id] = fieldToZod(field);
  }
  return z.object(shape);
}
```

---

## 6. Svelte 5 Components

Svelte 5 runes (`$props`, `$state`, `$derived`, `$effect`) 사용. 모든 컴포넌트는 `.svelte` 확장자.

### 6.1 `FormRenderer.svelte` (기안 작성 시)

```svelte
<script lang="ts">
  import type { FormSchema } from '$lib/types/approval';
  import FormField from './FormField.svelte';

  type Props = {
    schema: FormSchema;
    value: Record<string, unknown>;
    errors?: Record<string, string>;
    readonly?: boolean;
    onChange?: (next: Record<string, unknown>) => void;
  };

  let { schema, value = $bindable(), errors = {}, readonly = false, onChange }: Props = $props();

  function updateField(id: string, next: unknown) {
    value = { ...value, [id]: next };
    onChange?.(value);
  }
</script>

<div class="form-renderer flex flex-col gap-4">
  {#each schema.fields as field (field.id)}
    <FormField
      {field}
      value={value[field.id]}
      error={errors[field.id]}
      {readonly}
      onChange={(next) => updateField(field.id, next)}
    />
  {/each}
</div>
```

### 6.2 `FormField.svelte`

```svelte
<script lang="ts">
  import type { FormField } from '$lib/types/approval';
  import AttachmentInput from './AttachmentInput.svelte';

  type Props = {
    field: FormField;
    value: unknown;
    error?: string;
    readonly?: boolean;
    onChange: (next: unknown) => void;
  };

  let { field, value, error, readonly = false, onChange }: Props = $props();
</script>

<label class="flex flex-col gap-1">
  <span class="text-sm font-medium">
    {field.label}
    {#if field.required}<span class="text-red-500">*</span>{/if}
  </span>

  {#if field.type === 'text'}
    <input
      type="text"
      class="rounded border px-3 py-2"
      class:border-red-500={error}
      value={value as string ?? ''}
      placeholder={field.placeholder}
      maxlength={field.maxLength}
      disabled={readonly}
      oninput={(e) => onChange(e.currentTarget.value)}
    />
  {:else if field.type === 'textarea'}
    <textarea
      class="rounded border px-3 py-2 min-h-24"
      class:border-red-500={error}
      value={value as string ?? ''}
      disabled={readonly}
      oninput={(e) => onChange(e.currentTarget.value)}
    ></textarea>
  {:else if field.type === 'number'}
    <div class="flex items-center gap-2">
      <input
        type="number"
        class="rounded border px-3 py-2 flex-1"
        value={value as number ?? ''}
        min={field.min}
        max={field.max}
        step={field.step}
        disabled={readonly}
        oninput={(e) => onChange(Number(e.currentTarget.value))}
      />
      {#if field.unit}<span class="text-sm text-gray-500">{field.unit}</span>{/if}
    </div>
  {:else if field.type === 'date'}
    <input
      type="date"
      class="rounded border px-3 py-2"
      value={value as string ?? ''}
      min={field.min}
      max={field.max}
      disabled={readonly}
      oninput={(e) => onChange(e.currentTarget.value)}
    />
  {:else if field.type === 'date-range'}
    <div class="flex gap-2">
      <input
        type="date"
        class="rounded border px-3 py-2"
        value={(value as { start?: string })?.start ?? ''}
        disabled={readonly}
        oninput={(e) => onChange({ ...(value as object ?? {}), start: e.currentTarget.value })}
      />
      <span class="self-center">~</span>
      <input
        type="date"
        class="rounded border px-3 py-2"
        value={(value as { end?: string })?.end ?? ''}
        disabled={readonly}
        oninput={(e) => onChange({ ...(value as object ?? {}), end: e.currentTarget.value })}
      />
    </div>
  {:else if field.type === 'select'}
    <select
      class="rounded border px-3 py-2"
      value={value as string ?? ''}
      disabled={readonly}
      onchange={(e) => onChange(e.currentTarget.value)}
    >
      <option value="">선택하세요</option>
      {#each field.options as opt}
        <option value={opt.value}>{opt.label}</option>
      {/each}
    </select>
  {:else if field.type === 'attachment'}
    <AttachmentInput {field} value={value as string[] ?? []} {readonly} {onChange} />
  {/if}

  {#if error}<span class="text-xs text-red-500">{error}</span>{/if}
  {#if field.help}<span class="text-xs text-gray-500">{field.help}</span>{/if}
</label>
```

### 6.3 `ApprovalLine.svelte`

```svelte
<script lang="ts">
  import type { ApprovalLineItem, ProfileLite } from '$lib/types/approval';
  import ApproverPicker from './ApproverPicker.svelte';

  type Props = {
    line: ApprovalLineItem[];
    profiles: Record<string, ProfileLite>;  // userId → profile
    editable?: boolean;
    onChange?: (next: ApprovalLineItem[]) => void;
  };

  let { line = $bindable(), profiles, editable = false, onChange }: Props = $props();
  let pickerOpen = $state(false);

  function remove(index: number) {
    line = line.filter((_, i) => i !== index);
    onChange?.(line);
  }

  function addApprover(userId: string, stepType: 'approval' | 'reference') {
    line = [...line, { userId, stepType }];
    onChange?.(line);
    pickerOpen = false;
  }

  function move(index: number, dir: -1 | 1) {
    const target = index + dir;
    if (target < 0 || target >= line.length) return;
    const next = [...line];
    [next[index], next[target]] = [next[target], next[index]];
    line = next;
    onChange?.(line);
  }
</script>

<div class="approval-line flex flex-col gap-2">
  <h3 class="text-sm font-semibold">결재선</h3>
  <ol class="flex flex-col gap-1">
    {#each line as item, index}
      {@const profile = profiles[item.userId]}
      <li class="flex items-center gap-2 rounded border px-3 py-2">
        <span class="w-6 text-sm text-gray-500">{index + 1}</span>
        <span class="flex-1">{profile?.displayName ?? '(알 수 없음)'}</span>
        <span class="text-xs px-2 py-1 rounded bg-gray-100">
          {item.stepType === 'approval' ? '결재' : '참조'}
        </span>
        {#if editable}
          <button type="button" class="text-xs" onclick={() => move(index, -1)}>↑</button>
          <button type="button" class="text-xs" onclick={() => move(index, 1)}>↓</button>
          <button type="button" class="text-xs text-red-500" onclick={() => remove(index)}>✕</button>
        {/if}
      </li>
    {/each}
  </ol>

  {#if editable}
    <button
      type="button"
      class="rounded border border-dashed px-3 py-2 text-sm"
      onclick={() => (pickerOpen = true)}
    >
      + 결재자 추가
    </button>
  {/if}

  {#if pickerOpen}
    <ApproverPicker onPick={addApprover} onClose={() => (pickerOpen = false)} />
  {/if}
</div>
```

### 6.4 재사용 컴포넌트 목록 (props 시그니처)

| 컴포넌트 | Props | 역할 |
|---|---|---|
| `FormRenderer` | `{ schema, value, errors?, readonly?, onChange? }` | JSON 스키마 → 동적 폼 |
| `FormField` | `{ field, value, error?, readonly?, onChange }` | 단일 필드 분기 렌더 |
| `AttachmentInput` | `{ field, value, readonly?, onChange }` | presigned URL 업로드 |
| `ApprovalLine` | `{ line, profiles, editable?, onChange? }` | 결재선 표시/편집 |
| `ApproverPicker` | `{ onPick, onClose }` | 조직도 모달 |
| `DocumentHeader` | `{ document, form }` | 문서번호·상태·기안자 표시 |
| `AttachmentList` | `{ attachments, readonly? }` | 첨부 리스트 |
| `AuditTimeline` | `{ audits }` | 감사 로그 타임라인 |
| `InboxTabs` | `{ active, counts, baseHref }` | 5탭 + 배지 |
| `TenantSwitcher` | `{ tenants, current }` | 테넌트 전환 드롭다운 |

---

## 7. 첨부파일 업로드 흐름 (presigned URL)

### 7.1 클라이언트

```typescript
// src/lib/client/uploadAttachment.ts
import { browser } from '$app/environment';
import { createBrowserClient } from '@supabase/ssr';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

/**
 * Storage 경로 규칙: {tenant_id}/{YYYY-MM}/{upload_uuid}.{ext}
 *  - YYYY-MM: Asia/Seoul 기준 업로드 월
 *  - 원본 파일명은 DB의 approval_attachments.file_name에만 저장
 *  - Storage 경로는 파일당 폴더 없음 (flat under YYYY-MM)
 */

// 안전한 확장자 추출: 확장자 없으면 'bin', 너무 길거나 비정상이면 'bin'
function extractExt(fileName: string): string {
  const match = /\.([a-zA-Z0-9]{1,10})$/.exec(fileName);
  return match ? match[1].toLowerCase() : 'bin';
}

// Asia/Seoul 기준 YYYY-MM
function currentMonthKST(): string {
  const now = new Date();
  // 'en-CA' locale returns 'YYYY-MM-DD'
  const kstDate = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Seoul',
    year: 'numeric',
    month: '2-digit'
  }).format(now);
  return kstDate; // 'YYYY-MM'
}

export async function uploadAttachment(
  tenantId: string,
  file: File
): Promise<{ attachmentId: string; storagePath: string }> {
  if (!browser) throw new Error('Client only');

  const supabase = createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);
  const uploadUuid = crypto.randomUUID();
  const ext = extractExt(file.name);
  const monthBucket = currentMonthKST();
  const storagePath = `${tenantId}/${monthBucket}/${uploadUuid}.${ext}`;

  const { error: upErr } = await supabase.storage
    .from('approval-attachments')
    .upload(storagePath, file, {
      cacheControl: '3600',
      upsert: false,
      contentType: file.type || 'application/octet-stream'
    });
  if (upErr) throw upErr;

  const { data: row, error: insErr } = await supabase
    .from('approval_attachments')
    .insert({
      tenant_id: tenantId,
      storage_path: storagePath,
      file_name: file.name,        // 원본 파일명 (다운로드 시 복원용)
      mime: file.type,
      size: file.size,
      uploaded_by: (await supabase.auth.getUser()).data.user!.id,
      document_id: null
    })
    .select('id')
    .single();
  if (insErr) {
    // orphan 방지: DB insert 실패 시 업로드 파일 즉시 삭제
    await supabase.storage.from('approval-attachments').remove([storagePath]);
    throw insErr;
  }
  return { attachmentId: row.id, storagePath };
}
```

### 7.2 서버 다운로드 URL 발급

```typescript
// src/lib/server/downloadUrl.ts

/**
 * Signed download URL 생성. Storage 경로는 upload_uuid.ext 형태지만
 * Content-Disposition 헤더로 원본 파일명을 복원한다.
 */
export async function createDownloadUrl(
  supabase: App.Locals['supabase'],
  storagePath: string,
  originalFileName: string
): Promise<string> {
  const { data, error } = await supabase.storage
    .from('approval-attachments')
    .createSignedUrl(storagePath, 60 * 5, {
      download: originalFileName
    });
  if (error) throw error;
  return data.signedUrl;
}

/**
 * 여러 첨부파일의 signed URL 일괄 발급 (문서 상세 load에서 사용)
 */
export async function createDownloadUrls(
  supabase: App.Locals['supabase'],
  attachments: Array<{ storage_path: string; file_name: string }>
): Promise<Map<string, string>> {
  const urls = new Map<string, string>();
  await Promise.all(
    attachments.map(async (a) => {
      const url = await createDownloadUrl(supabase, a.storage_path, a.file_name);
      urls.set(a.storage_path, url);
    })
  );
  return urls;
}
```

---

## 8. 핵심 알고리즘

### 8.1 결재선 스냅샷

- 상신 시점에 `approval_steps` INSERT — 이후 인사발령/양식 변경과 독립
- 결재선 배열(`ApprovalLineItem[]`) → `step_index` 0부터 순차 INSERT
- `step_type='reference'`는 `current_step_index` 진행에 영향 X — `fn_approve_step`에서 다음 approval step으로 skip

### 8.2 current_step_index 진행 규칙

```
steps = [
  { index: 0, type: approval, approver: A, status: pending },
  { index: 1, type: reference, approver: B, status: pending },
  { index: 2, type: approval, approver: C, status: pending }
]

A 승인
  → steps[0].status = 'approved'
  → 다음 approval step = index 2
  → doc.current_step_index = 2
  → reference step(index 1)은 건드리지 않음 (감사용으로 pending 유지 가능)

C 승인
  → steps[2].status = 'approved'
  → 다음 approval step 없음
  → doc.status = 'completed'
```

**note**: v1.0에서는 reference step은 결재 진행에 무관. 단순히 "이 사람도 읽을 수 있다"는 표식. v1.2에서 공람 확인 기능을 위해 status를 'viewed'로 업데이트하는 API 추가 예정.

### 8.3 문서번호 발급 동시성

- `fn_next_doc_number`는 `INSERT ... ON CONFLICT DO UPDATE` 패턴으로 atomic
- 날짜 경계(자정)에 첫 호출이 새 row 생성, 이후 +1 누적
- Asia/Seoul 타임존 기준으로 일자 경계 결정

### 8.4 RLS 재귀 방지

`is_tenant_member`, `is_tenant_admin`은 `SECURITY DEFINER`로 선언되어 함수 내부에서는 RLS 우회. 호출자는 여전히 RLS 제약 받음.

---

## 9. Form Schema 예시 (휴가신청서)

UI가 이 구조를 받아 FormRenderer로 렌더링.

```json
{
  "version": 1,
  "fields": [
    {
      "id": "leave_type",
      "type": "select",
      "label": "휴가 종류",
      "required": true,
      "options": [
        { "value": "annual", "label": "연차" },
        { "value": "half", "label": "반차" },
        { "value": "sick", "label": "병가" },
        { "value": "family", "label": "경조사" }
      ]
    },
    {
      "id": "period",
      "type": "date-range",
      "label": "휴가 기간",
      "required": true
    },
    {
      "id": "reason",
      "type": "textarea",
      "label": "사유",
      "required": true,
      "maxLength": 500
    },
    {
      "id": "contact",
      "type": "text",
      "label": "비상 연락처"
    }
  ]
}
```

기안자가 입력한 content:

```json
{
  "leave_type": "annual",
  "period": { "start": "2026-05-01", "end": "2026-05-03" },
  "reason": "개인 사유",
  "contact": "010-1234-5678"
}
```

---

## 10. 프로젝트 의존성

### 10.1 `package.json` (초기)

```json
{
  "name": "rigel",
  "version": "0.1.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite dev",
    "build": "vite build",
    "preview": "vite preview",
    "check": "svelte-kit sync && svelte-check --tsconfig ./tsconfig.json",
    "gen:types": "supabase gen types typescript --local > src/lib/types/database.types.ts"
  },
  "devDependencies": {
    "@sveltejs/adapter-node": "^5.2.0",
    "@sveltejs/kit": "^2.15.0",
    "@sveltejs/vite-plugin-svelte": "^4.0.0",
    "@types/node": "^22.0.0",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "svelte": "^5.14.0",
    "svelte-check": "^4.1.0",
    "tailwindcss": "^3.4.17",
    "tslib": "^2.8.1",
    "typescript": "^5.7.2",
    "vite": "^6.0.0"
  },
  "dependencies": {
    "@supabase/ssr": "^0.5.2",
    "@supabase/supabase-js": "^2.47.0",
    "zod": "^3.24.0"
  }
}
```

### 10.2 `svelte.config.js`

```javascript
import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
    csrf: { checkOrigin: true },
    alias: {
      $lib: 'src/lib'
    }
  },
  compilerOptions: {
    runes: true
  }
};

export default config;
```

---

## 11. 환경변수

`.env.local`:

```
PUBLIC_SUPABASE_URL=http://127.0.0.1:54321
PUBLIC_SUPABASE_ANON_KEY=<from supabase status>
```

`.env.example`:

```
PUBLIC_SUPABASE_URL=
PUBLIC_SUPABASE_ANON_KEY=
```

---

## 12. 수동 테스트 체크리스트 (Do 단계 M9에서 사용)

### 12.1 인증 & 테넌트

- [ ] `/signup`으로 회원가입 → email confirmation off → 바로 로그인
- [ ] 테넌트 0개 상태에서 `/` 접근 → `/onboarding/create-tenant` 리디렉트
- [ ] 테넌트 생성 → `/t/{slug}/approval/inbox` 자동 이동 + 기본 양식 5종 존재 확인
- [ ] 로그아웃 후 `/t/{slug}/...` 접근 → `/login?redirect=...` 리디렉트
- [ ] 다른 사용자 A, B 생성 → 서로 다른 테넌트 생성 → A가 B의 `/t/{b-slug}/approval/inbox` 접근 시 404

### 12.2 결재 플로우

- [ ] 휴가신청서 기안 작성 → 기간 입력 → 결재자 B 지정 → 첨부 1개 → 상신
- [ ] B로 로그인 → `/t/{slug}/approval/inbox?tab=pending` → 문서 표시
- [ ] 문서 상세 → 승인 → status `completed`, steps[0] approved
- [ ] 다른 기안 → 3단계 결재선 (A→B→C) → B가 반려 → C는 skipped, doc rejected
- [ ] 기안 → 회수 → status `withdrawn`, 이후 단계 skipped

### 12.3 멀티 테넌트 격리

- [ ] 테넌트 1의 document_id를 테넌트 2 멤버가 직접 URL로 접근 → 404
- [ ] Storage 경로를 테넌트 2 사용자가 다운로드 시도 → 403
- [ ] `approval_documents` 테이블 직접 쿼리 (Supabase studio) → 본인 테넌트만 조회됨

### 12.4 관리자 & 양식

- [ ] admin 권한 없는 사용자가 `/t/{slug}/admin/forms` 접근 → 403
- [ ] admin이 양식 JSON 편집 → 저장 → 발행 → 새 기안에 반영
- [ ] 이미 상신된 문서는 양식 수정 영향 없음 (snapshot 확인)
- [ ] 초대 링크 생성 → 다른 계정으로 수락 → 테넌트 멤버 추가

### 12.5 Progressive Enhancement

- [ ] 브라우저 JS 비활성화 상태에서 `/login` → 로그인 가능
- [ ] JS-off 상태에서 결재 승인/반려 → action 동작

---

## 13. Design Complete Criteria

- [x] TypeScript 타입 정의 (도메인 + App.Locals)
- [x] 13개 migration SQL 전체 (DDL + RLS)
- [x] 7개 plpgsql RPC 함수 본문
- [x] Storage 버킷 + RLS 정책
- [x] Svelte 5 컴포넌트 props 시그니처 9개
- [x] Zod 스키마 8개
- [x] Load/Action 시그니처 (대표 3개 + 패턴 문서화)
- [x] Form Schema JSON 예시
- [x] 프로젝트 의존성(package.json) + svelte.config.js
- [x] 수동 테스트 체크리스트 (M9 게이트)

---

## 14. Risk Update (Plan → Design에서 추가 발견)

| # | 리스크 | 발견 시점 | 완화책 |
|---|---|---|---|
| 9 | RLS 정책의 중첩 EXISTS 쿼리 성능 | Design 단계 | 인덱스 4개 추가 (`ad_drafter_idx`, `as_approver_pending_idx`, `aal_document_idx`, `tm_user_idx`). Supabase Studio 플래너로 실제 계획 확인 후 조정 |
| 10 | Zod 동적 content 검증 타입 안정성 | Design 단계 | `buildContentSchema`가 any 반환 → 런타임 검증만 보장. TS 컴파일 타임 안정성은 포기(JSONB 특성상 불가피) |
| 11 | 결재선 배열 JSONB의 FK 무결성 미보장 | Design 단계 | Form Action에서 Zod로 userId 포맷 검증 + `fn_submit_draft` 내부에서 approval_steps INSERT 시 FK 실패 시 트랜잭션 전체 롤백 |
| 12 | Storage orphan file (업로드 후 상신 안 함) | Design 단계 | v1.0: 클라이언트 업로드 함수에서 DB insert 실패 시 즉시 Storage 파일 삭제 (catch→remove). v1.1 pg_cron: `approval_attachments WHERE document_id IS NULL AND uploaded_at < now() - interval '6 hours'` → 해당 `storage_path` 삭제 + row 삭제. 월 버킷 구조라 `YYYY-MM` prefix별 스캔 가능 |
| 14 | **RLS 정책 스타일로 인한 performance linter WARN** | M2 실제 적용 후 발견 | M2 완료 직후 Supabase linter가 `auth_rls_initplan`(3건) + `multiple_permissive_policies`(3건) 보고. 섹션 2.0 "RLS 작성 규칙" 으로 표준화. `0006_m2_linter_fixes` 마이그레이션으로 교정. M4/M5의 approval_* 정책은 처음부터 이 규칙으로 작성할 것 |
| 15 | **RLS 정책 간 무한 재귀 (ad_select ↔ as_select 교차 EXISTS)** | M5 smoke test에서 발견 | `ad_select`가 `approval_steps`에 EXISTS, `as_select`가 `approval_documents`에 EXISTS → 서로의 RLS trigger → `infinite recursion detected in policy`. 해결책: **SECURITY DEFINER helper 함수** (`is_document_drafter` / `is_document_approver` / `get_document_tenant`) 도입 — 함수 내부 쿼리는 RLS 우회. `0017_m5_rls_recursion_fix`로 ad/as/aal/att SELECT 정책 전면 재작성. **교훈**: 테이블 간 양방향 EXISTS는 RLS에 절대 쓰지 말 것. 한쪽은 helper 함수로 우회 |
| 13 | `fn_approve_step` 내부 reference step 건드리지 않음 → "승인이 끝났는데 reference step이 pending으로 남음" UI 혼란 | Design 단계 | 문서 완료/반려 시 남은 pending reference step을 'skipped'로 일괄 업데이트 (fn_approve_step 마지막 단계에서만, fn_reject_step도 동일) |

> **Risk #13 수정사항**: 위 `fn_approve_step` 코드의 "마지막 단계였음 → 완료" 분기에 다음을 추가해야 함:
> ```sql
> UPDATE public.approval_steps
> SET status = 'skipped'
> WHERE document_id = p_document_id
>   AND status = 'pending';
> ```
> Do 단계에서 실제 migration 작성 시 반영.

---

## 15. References

- Plan: [docs/01-plan/features/approval-mvp.plan.md](../../01-plan/features/approval-mvp.plan.md)
- Research: [docs/01-research/korean-groupware-approval-review.md](../../01-research/korean-groupware-approval-review.md)
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security
- @supabase/ssr: https://supabase.com/docs/guides/auth/server-side/sveltekit
- SvelteKit Form Actions: https://svelte.dev/docs/kit/form-actions
- Svelte 5 Runes: https://svelte.dev/docs/svelte/what-are-runes

---

> **다음 단계**: `/pdca do approval-mvp` — M1 SvelteKit 스캐폴딩부터 M10 v1.0 태깅까지 순차 구현
