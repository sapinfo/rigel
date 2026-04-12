# Design — 전자결재 v1.1 Korean Exceptions

> 전결·대결·후결·부재자동 — 상세 설계 문서
> Base: v1.0.0 (`d957381`), Plan: [전자결재-v1.1-korean-exceptions.plan.md](../../01-plan/features/전자결재-v1.1-korean-exceptions.plan.md)
> 작성일: 2026-04-11
> Delivery: Sequential 4-Slice (M11 전결 → M12 대결 → M13 후결 → M14 부재자동)

---

## Executive Summary

| 항목 | 값 |
|---|---|
| Base | v1.0.0 (25 smoke / match 100%) |
| Migrations | 0019~0029 (11건, TX 외부 분리 포함) |
| 신규 RPC | fn_submit_draft_v2 (교체), fn_approve_with_proxy (fn_approve_step 확장), fn_submit_post_facto, fn_auto_delegate_on_absence |
| 신규 테이블 | delegation_rules, user_absences |
| 신규 enum | absence_type; audit_action +4; document_status +1 |
| 신규 라우트 | `/admin/delegations/*`, `/admin/absences/*`, `/my/absences/*` |
| 변경 컴포넌트 | ApprovalLine, ApprovalPanel |
| Smoke | 25 → 40 (+15) |

### Value Delivered

| 관점 | 내용 |
|---|---|
| **Problem** | v1.0 순차승인만 → 한국 SMB 필수 4종 부재로 실사용 불가 |
| **Solution** | DB·RPC·UI 전 레이어를 스냅샷·원자성·감사로그 원칙 하에 확장 |
| **Function UX Effect** | 부재 등록만으로 결재 자동 전환, 긴급건 후결, 금액/양식별 자동 전결 |
| **Core Value** | 시장 진입 MVP + 컴플라이언스 감사 트레일 완비 |

### 핵심 정책 (Plan §1.4 고정)

| 정책 | 값 |
|---|---|
| 전결 ↔ 부재 충돌 | **부재 > 전결** (fn_submit_draft는 skip, fn_approve_step은 proxy 체크 → 자연 배타) |
| 후결 원자성 | 단일 TX + `SELECT form FOR UPDATE` |
| 부재 자동 전환 | Trigger (AFTER INSERT/UPDATE) + 매일 00:00 pg_cron 백업 |
| 위임 체인 깊이 | depth ≥ 2 reject (`RAISE EXCEPTION`) |

---

## 1. TypeScript Types & Interfaces

파일: `src/lib/types/approval.ts` (기존 파일에 추가)

```ts
// ─── 1.1 Enum ──────────────────────────────────────────
export type AbsenceType = 'annual' | 'sick' | 'business_trip' | 'other';

export type AuditAction =
  // v1.0 기존
  | 'submitted' | 'approved' | 'rejected' | 'withdrawn' | 'commented' | 'skipped'
  // v1.1 신규
  | 'delegated'
  | 'approved_by_proxy'
  | 'submitted_post_facto'
  | 'auto_delegated';

export type DocumentStatus =
  | 'draft' | 'pending' | 'approved' | 'rejected' | 'withdrawn'
  | 'pending_post_facto';  // v1.1 신규

// ─── 1.2 DelegationRule ────────────────────────────────
export interface DelegationRule {
  id: string;
  tenant_id: string;
  delegator_user_id: string;   // 원 승인자
  delegate_user_id: string;    // 전결 수행자
  form_id: string | null;      // null = 전 양식
  amount_limit: number | null; // null = 금액 무관
  effective_from: string;      // ISO
  effective_to: string | null; // null = 상시
  created_at: string;
  created_by: string;
}

// 목록 화면용 (join된 profile 포함)
export interface DelegationRuleWithProfiles extends DelegationRule {
  delegator: { user_id: string; full_name: string; email: string };
  delegate:  { user_id: string; full_name: string; email: string };
  form: { id: string; code: string; name: string } | null;
}

// ─── 1.3 UserAbsence ───────────────────────────────────
export interface UserAbsence {
  id: string;
  tenant_id: string;
  user_id: string;
  delegate_user_id: string;
  absence_type: AbsenceType;
  scope_form_id: string | null; // null = 전체 결재 대리
  start_at: string;
  end_at: string;
  reason: string | null;
  created_at: string;
}

export interface UserAbsenceWithProfiles extends UserAbsence {
  user:     { user_id: string; full_name: string; email: string };
  delegate: { user_id: string; full_name: string; email: string };
  scope_form: { id: string; code: string; name: string } | null;
}

// ─── 1.4 ApprovalStep 확장 ─────────────────────────────
// 기존 ApprovalStep 인터페이스에 아래 필드 추가
export interface ApprovalStepV11Extension {
  acted_by_proxy_user_id: string | null; // 대리인이 실제 수행한 경우
}

// ─── 1.5 AuditLog 확장 ─────────────────────────────────
export interface ApprovalAuditLogV11Extension {
  acted_by_proxy_user_id: string | null;
}

// ─── 1.6 RPC Response 형태 ─────────────────────────────
export interface SubmitPostFactoInput {
  form_id: string;
  title: string;
  data: Record<string, unknown>;
  approver_line: Array<{ user_id: string; role: 'reviewer' | 'approver' | 'reference' }>;
  reason: string; // 필수
}
```

---

## 2. Database Migrations

### 2.0 RLS 작성 규칙 (v1.0 교훈 재강조 — 위반 시 advisor WARN)

1. **`auth.uid()` 는 반드시 `(SELECT auth.uid())` 로 래핑** — InitPlan 캐싱
2. **`FOR ALL` 금지** — SELECT/INSERT/UPDATE/DELETE 개별
3. **같은 action에 permissive 정책 중복 금지** — OR로 합침
4. **Helper 함수는 `SECURITY DEFINER + STABLE`** — v1.0의 `is_tenant_member`, `is_tenant_owner_or_admin` 재사용
5. **양방향 EXISTS 금지** — 한쪽은 SECURITY DEFINER helper로 우회
6. **`ALTER TYPE ADD VALUE`는 트랜잭션 외부** → migration 파일 단독 분리

### 2.1 Migration 0019 — delegation_rules

```sql
-- supabase/migrations/0019_delegation_rules.sql
BEGIN;

CREATE TABLE public.delegation_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  delegator_user_id uuid NOT NULL REFERENCES auth.users(id),
  delegate_user_id  uuid NOT NULL REFERENCES auth.users(id),
  form_id uuid NULL REFERENCES public.approval_forms(id) ON DELETE CASCADE,
  amount_limit numeric(14,2) NULL,
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_to   timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL REFERENCES auth.users(id),
  CONSTRAINT delegation_rules_self_check CHECK (delegator_user_id <> delegate_user_id),
  CONSTRAINT delegation_rules_range_check CHECK (
    effective_to IS NULL OR effective_to > effective_from
  ),
  CONSTRAINT delegation_rules_amount_check CHECK (
    amount_limit IS NULL OR amount_limit >= 0
  )
);

CREATE INDEX idx_delegation_rules_lookup
  ON public.delegation_rules (tenant_id, delegator_user_id, form_id, effective_from DESC);

COMMENT ON TABLE public.delegation_rules IS
  'Delegation (전결) rules. Matched at fn_submit_draft snapshot time.';

-- RLS
ALTER TABLE public.delegation_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY delegation_rules_select ON public.delegation_rules
  FOR SELECT
  USING (public.is_tenant_member(tenant_id, (SELECT auth.uid())));

CREATE POLICY delegation_rules_insert ON public.delegation_rules
  FOR INSERT
  WITH CHECK (public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid())));

CREATE POLICY delegation_rules_update ON public.delegation_rules
  FOR UPDATE
  USING (public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid())))
  WITH CHECK (public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid())));

CREATE POLICY delegation_rules_delete ON public.delegation_rules
  FOR DELETE
  USING (public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid())));

-- 직접 INSERT 차단 (ad_no_direct_insert 패턴)
-- 관리자 UI는 RPC fn_create_delegation_rule 경유
-- 단 SELECT는 허용 (조회용)

COMMIT;
```

### 2.2 Migration 0020 — audit_action 확장 (단독, TX 외부)

```sql
-- supabase/migrations/0020_audit_action_delegated.sql
-- NOTE: ALTER TYPE ADD VALUE는 트랜잭션 외부에서만 실행 가능.
-- Supabase MCP apply_migration이 각 파일을 독립 실행하므로 BEGIN/COMMIT 없이 작성.

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'delegated';
```

### 2.3 Migration 0021 — fn_submit_draft v2

```sql
-- supabase/migrations/0021_fn_submit_draft_v2.sql
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_submit_draft(
  p_form_id uuid,
  p_title text,
  p_data jsonb,
  p_approver_line jsonb,  -- [{user_id, role}, ...]
  p_attachments jsonb DEFAULT '[]'::jsonb
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
  v_drafter uuid := auth.uid();
  v_document_id uuid;
  v_form record;
  v_amount numeric(14,2) := NULL;
  v_approver jsonb;
  v_step_order int := 1;
  v_delegation_rule record;
  v_final_approver_id uuid;
  v_step_status text;
  v_snapshot jsonb;
BEGIN
  -- 1. form 스냅샷 확보 (v1.0 동일)
  SELECT f.* INTO v_form
    FROM public.approval_forms f
   WHERE f.id = p_form_id
     FOR UPDATE;

  IF v_form.id IS NULL THEN
    RAISE EXCEPTION 'form not found' USING ERRCODE = 'P0002';
  END IF;

  v_tenant_id := v_form.tenant_id;
  v_snapshot := v_form.schema;

  -- 2. amount 추출 (form.metadata.amount_field 설정이 있으면 p_data에서 해당 필드 추출)
  IF v_form.metadata ? 'amount_field' THEN
    v_amount := COALESCE(
      (p_data ->> (v_form.metadata ->> 'amount_field'))::numeric,
      NULL
    );
  END IF;

  -- 3. document INSERT
  INSERT INTO public.approval_documents (
    tenant_id, form_id, form_schema_snapshot,
    drafter_user_id, title, data, status, created_at
  ) VALUES (
    v_tenant_id, p_form_id, v_snapshot,
    v_drafter, p_title, p_data, 'pending', now()
  ) RETURNING id INTO v_document_id;

  -- 4. approver_line 순회 + delegation 매칭
  FOR v_approver IN SELECT * FROM jsonb_array_elements(p_approver_line)
  LOOP
    v_final_approver_id := (v_approver ->> 'user_id')::uuid;
    v_step_status := 'pending';

    -- delegation 매칭: approver 역할일 때만 (reviewer/reference는 제외)
    IF (v_approver ->> 'role') = 'approver' THEN
      SELECT * INTO v_delegation_rule
        FROM public.delegation_rules dr
       WHERE dr.tenant_id = v_tenant_id
         AND dr.delegator_user_id = v_final_approver_id
         AND (dr.form_id = p_form_id OR dr.form_id IS NULL)
         AND (dr.amount_limit IS NULL OR
              (v_amount IS NOT NULL AND v_amount <= dr.amount_limit))
         AND dr.effective_from <= now()
         AND (dr.effective_to IS NULL OR dr.effective_to > now())
       ORDER BY
         (dr.form_id IS NULL) ASC,          -- 구체 form 우선
         dr.amount_limit ASC NULLS LAST,    -- 타이트한 한도 우선
         dr.effective_from DESC             -- 최신 우선
       LIMIT 1;

      IF v_delegation_rule.id IS NOT NULL THEN
        v_step_status := 'skipped';
      END IF;
    END IF;

    INSERT INTO public.approval_steps (
      tenant_id, document_id, step_order,
      approver_user_id, role, status, created_at
    ) VALUES (
      v_tenant_id, v_document_id, v_step_order,
      v_final_approver_id, v_approver ->> 'role', v_step_status, now()
    );

    -- 감사 로그: delegation으로 skip된 경우
    IF v_step_status = 'skipped' AND v_delegation_rule.id IS NOT NULL THEN
      INSERT INTO public.approval_audit_logs (
        tenant_id, document_id, actor_user_id, action, comment, created_at
      ) VALUES (
        v_tenant_id, v_document_id, v_drafter, 'delegated',
        format('delegated to %s (rule %s)',
               v_delegation_rule.delegate_user_id, v_delegation_rule.id),
        now()
      );
    END IF;

    v_step_order := v_step_order + 1;
  END LOOP;

  -- 5. 첨부 처리 (v1.0 동일, 생략)
  -- ...

  -- 6. 제출 감사 로그
  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_user_id, action, created_at
  ) VALUES (
    v_tenant_id, v_document_id, v_drafter, 'submitted', now()
  );

  RETURN v_document_id;
END;
$$;

-- 직접 INSERT 차단 유지 (v1.0 ad_no_direct_insert 패턴)
GRANT EXECUTE ON FUNCTION public.fn_submit_draft(uuid, text, jsonb, jsonb, jsonb) TO authenticated;

COMMIT;
```

### 2.4 Migration 0022 — user_absences

```sql
-- supabase/migrations/0022_user_absences.sql
BEGIN;

CREATE TYPE public.absence_type AS ENUM ('annual', 'sick', 'business_trip', 'other');

CREATE TABLE public.user_absences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  delegate_user_id uuid NOT NULL REFERENCES auth.users(id),
  absence_type public.absence_type NOT NULL DEFAULT 'other',
  scope_form_id uuid NULL REFERENCES public.approval_forms(id) ON DELETE CASCADE,
  start_at timestamptz NOT NULL,
  end_at   timestamptz NOT NULL,
  reason text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_absences_self_check CHECK (user_id <> delegate_user_id),
  CONSTRAINT user_absences_range_check CHECK (end_at > start_at)
);

CREATE INDEX idx_user_absences_active
  ON public.user_absences (tenant_id, user_id, start_at, end_at);

CREATE INDEX idx_user_absences_delegate
  ON public.user_absences (tenant_id, delegate_user_id);

COMMENT ON TABLE public.user_absences IS
  'User absence records. Used for proxy approval and auto-delegation.';

ALTER TABLE public.user_absences ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_absences_select ON public.user_absences
  FOR SELECT
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid()))
  );

CREATE POLICY user_absences_insert ON public.user_absences
  FOR INSERT
  WITH CHECK (
    -- self-service OR admin
    (user_id = (SELECT auth.uid())
     AND public.is_tenant_member(tenant_id, (SELECT auth.uid())))
    OR public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid()))
  );

CREATE POLICY user_absences_update ON public.user_absences
  FOR UPDATE
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid()))
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid()))
  );

CREATE POLICY user_absences_delete ON public.user_absences
  FOR DELETE
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_owner_or_admin(tenant_id, (SELECT auth.uid()))
  );

COMMIT;
```

### 2.5 Migration 0023 — Proxy Columns + audit_action 확장

```sql
-- supabase/migrations/0023_proxy_columns.sql
-- 컬럼 추가는 TX 안에서, enum 확장은 별도 파일(0023b)로 분리 권장.
-- 여기서는 컬럼만.

BEGIN;

ALTER TABLE public.approval_steps
  ADD COLUMN acted_by_proxy_user_id uuid NULL REFERENCES auth.users(id);

ALTER TABLE public.approval_audit_logs
  ADD COLUMN acted_by_proxy_user_id uuid NULL REFERENCES auth.users(id);

COMMENT ON COLUMN public.approval_steps.acted_by_proxy_user_id IS
  'Non-null when the action was performed by a proxy (absence delegate).';
COMMENT ON COLUMN public.approval_audit_logs.acted_by_proxy_user_id IS
  'Non-null when the action was performed by a proxy.';

COMMIT;
```

```sql
-- supabase/migrations/0023b_audit_action_proxy.sql (TX 외부)
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'approved_by_proxy';
```

### 2.6 Migration 0024 — fn_approve_with_proxy

```sql
-- supabase/migrations/0024_fn_approve_with_proxy.sql
BEGIN;

-- Helper: 활성 absence 조회 (scope 필터 포함)
CREATE OR REPLACE FUNCTION public.fn_find_active_absence(
  p_tenant_id uuid, p_user_id uuid, p_form_id uuid
) RETURNS public.user_absences
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.*
    FROM public.user_absences a
   WHERE a.tenant_id = p_tenant_id
     AND a.user_id = p_user_id
     AND now() BETWEEN a.start_at AND a.end_at
     AND (a.scope_form_id IS NULL OR a.scope_form_id = p_form_id)
   ORDER BY a.start_at DESC
   LIMIT 1;
$$;

-- fn_approve_step 교체 (v1.0 확장)
CREATE OR REPLACE FUNCTION public.fn_approve_step(
  p_step_id uuid,
  p_comment text DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_step record;
  v_doc record;
  v_acting uuid := auth.uid();
  v_absence public.user_absences;
  v_acting_absence public.user_absences;
  v_proxy uuid := NULL;
BEGIN
  -- 1. Lock step
  SELECT s.* INTO v_step
    FROM public.approval_steps s
   WHERE s.id = p_step_id
     FOR UPDATE;

  IF v_step.id IS NULL THEN
    RAISE EXCEPTION 'step not found';
  END IF;
  IF v_step.status <> 'pending' THEN
    RAISE EXCEPTION 'step not pending (current: %)', v_step.status;
  END IF;

  SELECT d.* INTO v_doc FROM public.approval_documents d WHERE d.id = v_step.document_id;

  -- 2. 권한 분기
  IF v_step.approver_user_id = v_acting THEN
    -- 본인 직접 승인 (v1.0 경로)
    v_proxy := NULL;
  ELSE
    -- Proxy 경로: 해당 approver의 활성 absence 확인
    v_absence := public.fn_find_active_absence(
      v_step.tenant_id, v_step.approver_user_id, v_doc.form_id
    );

    IF v_absence.id IS NULL THEN
      RAISE EXCEPTION 'not authorized';
    END IF;

    IF v_absence.delegate_user_id <> v_acting THEN
      RAISE EXCEPTION 'not authorized';
    END IF;

    -- 체인 깊이 제한: acting_user도 absence면 거부
    v_acting_absence := public.fn_find_active_absence(
      v_step.tenant_id, v_acting, v_doc.form_id
    );
    IF v_acting_absence.id IS NOT NULL THEN
      RAISE EXCEPTION 'proxy chain depth exceeded';
    END IF;

    v_proxy := v_acting;
  END IF;

  -- 3. 승인 처리
  UPDATE public.approval_steps
     SET status = 'approved',
         acted_at = now(),
         acted_by_proxy_user_id = v_proxy,
         comment = p_comment
   WHERE id = p_step_id;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_user_id, action,
    comment, acted_by_proxy_user_id, created_at
  ) VALUES (
    v_step.tenant_id, v_step.document_id,
    COALESCE(v_proxy, v_acting),
    CASE WHEN v_proxy IS NULL THEN 'approved' ELSE 'approved_by_proxy' END,
    p_comment, v_proxy, now()
  );

  -- 4. 다음 step 활성화 or 문서 완료 (v1.0 Risk #13 로직 유지)
  PERFORM public.fn_advance_document(v_step.document_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_approve_step(uuid, text) TO authenticated;

COMMIT;
```

### 2.7 Migration 0025 — document_status + audit_action 확장 (TX 외부)

```sql
-- supabase/migrations/0025_post_facto_status.sql
ALTER TYPE public.document_status ADD VALUE IF NOT EXISTS 'pending_post_facto';
ALTER TYPE public.audit_action    ADD VALUE IF NOT EXISTS 'submitted_post_facto';
```

### 2.8 Migration 0026 — fn_submit_post_facto

```sql
-- supabase/migrations/0026_fn_submit_post_facto.sql
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_submit_post_facto(
  p_form_id uuid,
  p_title text,
  p_data jsonb,
  p_approver_line jsonb,
  p_reason text  -- NOT NULL 로 강제 (런타임 체크)
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant_id uuid;
  v_drafter uuid := auth.uid();
  v_document_id uuid;
  v_form record;
  v_amount numeric(14,2) := NULL;
  v_approver jsonb;
  v_step_order int := 1;
  v_delegation_rule record;
  v_step_status text;
  v_snapshot jsonb;
BEGIN
  -- 1. 사유 필수 검증
  IF p_reason IS NULL OR length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'post-facto reason required';
  END IF;

  -- 2. form 스냅샷 (단일 TX, FOR UPDATE)
  SELECT f.* INTO v_form
    FROM public.approval_forms f
   WHERE f.id = p_form_id
     FOR UPDATE;

  IF v_form.id IS NULL THEN
    RAISE EXCEPTION 'form not found';
  END IF;
  v_tenant_id := v_form.tenant_id;
  v_snapshot := v_form.schema;

  -- 3. amount 추출
  IF v_form.metadata ? 'amount_field' THEN
    v_amount := COALESCE(
      (p_data ->> (v_form.metadata ->> 'amount_field'))::numeric,
      NULL
    );
  END IF;

  -- 4. document INSERT (status = pending_post_facto)
  INSERT INTO public.approval_documents (
    tenant_id, form_id, form_schema_snapshot,
    drafter_user_id, title, data, status, created_at
  ) VALUES (
    v_tenant_id, p_form_id, v_snapshot,
    v_drafter, p_title, p_data, 'pending_post_facto', now()
  ) RETURNING id INTO v_document_id;

  -- 5. approver_line + delegation 매칭 (fn_submit_draft와 동일 로직)
  FOR v_approver IN SELECT * FROM jsonb_array_elements(p_approver_line)
  LOOP
    v_step_status := 'pending';

    IF (v_approver ->> 'role') = 'approver' THEN
      SELECT * INTO v_delegation_rule
        FROM public.delegation_rules dr
       WHERE dr.tenant_id = v_tenant_id
         AND dr.delegator_user_id = (v_approver ->> 'user_id')::uuid
         AND (dr.form_id = p_form_id OR dr.form_id IS NULL)
         AND (dr.amount_limit IS NULL OR
              (v_amount IS NOT NULL AND v_amount <= dr.amount_limit))
         AND dr.effective_from <= now()
         AND (dr.effective_to IS NULL OR dr.effective_to > now())
       ORDER BY
         (dr.form_id IS NULL) ASC,
         dr.amount_limit ASC NULLS LAST,
         dr.effective_from DESC
       LIMIT 1;

      IF v_delegation_rule.id IS NOT NULL THEN
        v_step_status := 'skipped';
      END IF;
    END IF;

    INSERT INTO public.approval_steps (
      tenant_id, document_id, step_order,
      approver_user_id, role, status, created_at
    ) VALUES (
      v_tenant_id, v_document_id, v_step_order,
      (v_approver ->> 'user_id')::uuid, v_approver ->> 'role', v_step_status, now()
    );

    IF v_step_status = 'skipped' AND v_delegation_rule.id IS NOT NULL THEN
      INSERT INTO public.approval_audit_logs (
        tenant_id, document_id, actor_user_id, action, comment, created_at
      ) VALUES (
        v_tenant_id, v_document_id, v_drafter, 'delegated',
        format('delegated to %s', v_delegation_rule.delegate_user_id), now()
      );
    END IF;

    v_step_order := v_step_order + 1;
  END LOOP;

  -- 6. 제출 감사 로그 (이유 포함)
  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_user_id, action, comment, created_at
  ) VALUES (
    v_tenant_id, v_document_id, v_drafter, 'submitted_post_facto', p_reason, now()
  );

  RETURN v_document_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_post_facto(uuid, text, jsonb, jsonb, text) TO authenticated;

COMMIT;
```

### 2.9 Migration 0027 — fn_auto_delegate_on_absence + audit enum (TX 외부 for enum)

```sql
-- supabase/migrations/0027_audit_auto_delegated.sql (TX 외부)
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'auto_delegated';
```

```sql
-- supabase/migrations/0027b_fn_auto_delegate_on_absence.sql
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_auto_delegate_on_absence(
  p_absence_id uuid
) RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_absence public.user_absences;
  v_reassigned int := 0;
  v_step record;
BEGIN
  SELECT * INTO v_absence FROM public.user_absences WHERE id = p_absence_id;
  IF v_absence.id IS NULL THEN
    RAISE EXCEPTION 'absence not found';
  END IF;

  -- 활성 기간 외면 no-op
  IF NOT (now() BETWEEN v_absence.start_at AND v_absence.end_at) THEN
    RETURN 0;
  END IF;

  -- scope 매칭 pending step 재배정
  FOR v_step IN
    SELECT s.*
      FROM public.approval_steps s
      JOIN public.approval_documents d ON d.id = s.document_id
     WHERE s.tenant_id = v_absence.tenant_id
       AND s.status = 'pending'
       AND s.approver_user_id = v_absence.user_id
       AND (v_absence.scope_form_id IS NULL OR d.form_id = v_absence.scope_form_id)
       FOR UPDATE
  LOOP
    UPDATE public.approval_steps
       SET approver_user_id = v_absence.delegate_user_id
     WHERE id = v_step.id;

    INSERT INTO public.approval_audit_logs (
      tenant_id, document_id, actor_user_id, action, comment,
      acted_by_proxy_user_id, created_at
    ) VALUES (
      v_step.tenant_id, v_step.document_id, v_absence.user_id,
      'auto_delegated',
      format('reassigned from %s to %s via absence %s',
             v_absence.user_id, v_absence.delegate_user_id, v_absence.id),
      v_absence.delegate_user_id, now()
    );

    v_reassigned := v_reassigned + 1;
  END LOOP;

  RETURN v_reassigned;
END;
$$;

COMMIT;
```

### 2.10 Migration 0028 — Trigger

```sql
-- supabase/migrations/0028_absence_trigger.sql
BEGIN;

CREATE OR REPLACE FUNCTION public.fn_absence_trigger_handler()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- NEW가 현재 활성 기간이면 자동 재배정
  IF NEW.start_at <= now() AND NEW.end_at > now() THEN
    PERFORM public.fn_auto_delegate_on_absence(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_absence_auto_delegate
  AFTER INSERT OR UPDATE OF delegate_user_id, start_at, end_at, scope_form_id
  ON public.user_absences
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_absence_trigger_handler();

COMMIT;
```

### 2.11 Migration 0029 — pg_cron 백업 (v1.1 첫 cron 도입)

```sql
-- supabase/migrations/0029_pg_cron_absence_backup.sql
BEGIN;

-- pg_cron extension 활성화 (Supabase cloud/local 모두 지원)
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 매일 00:00 KST (UTC 15:00 전날) — pg_cron은 UTC 기준
SELECT cron.schedule(
  'absence-auto-delegate-daily-backup',
  '0 15 * * *',  -- UTC 15:00 = KST 00:00
  $$
    SELECT public.fn_auto_delegate_on_absence(id)
      FROM public.user_absences
     WHERE now() BETWEEN start_at AND end_at
  $$
);

COMMENT ON EXTENSION pg_cron IS 'v1.1 introduces pg_cron for absence backup job';

COMMIT;
```

### 2.12 Advisor 체크 항목

| Check | 기준 |
|---|---|
| `auth_rls_initplan` | 새 정책 모두 `(SELECT auth.uid())` 래핑 → **0 WARN** |
| `multiple_permissive_policies` | action별 단일 정책 → **0 WARN** |
| `function_search_path_mutable` | 모든 신규 함수 `SET search_path = public` → **0 WARN** |
| `unindexed_foreign_key` | delegation_rules / user_absences 외래키 인덱스 확인 |
| `duplicate_index` | idx_user_absences_active vs _delegate 중복 없음 |

---

## 3. RPC 호출 계약 (클라이언트 관점)

### 3.1 fn_submit_draft (v2, signature 동일)

```ts
// src/routes/t/[tenantSlug]/approval/drafts/new/[formCode]/+page.server.ts
const { data: docId, error } = await supabase.rpc('fn_submit_draft', {
  p_form_id: form.id,
  p_title: input.title,
  p_data: input.data,  // form values
  p_approver_line: input.approver_line,
  p_attachments: uploadedAttachments
});
```

Delegation matching은 RPC 내부 snapshot이므로 클라이언트 로직 변경 없음.

### 3.2 fn_approve_step (signature 동일, proxy 내부 처리)

```ts
const { error } = await supabase.rpc('fn_approve_step', {
  p_step_id: step.id,
  p_comment: comment
});
// 클라이언트는 본인/대리인 구분 필요 없음. RPC 내부에서 자동 처리.
```

UI는 활성 absence를 조회해서 "대리 승인" 라벨만 바꿈 (§7 참조).

### 3.3 fn_submit_post_facto (신규)

```ts
const { data: docId, error } = await supabase.rpc('fn_submit_post_facto', {
  p_form_id: form.id,
  p_title: input.title,
  p_data: input.data,
  p_approver_line: input.approver_line,
  p_reason: input.post_facto_reason  // required
});
```

### 3.4 fn_auto_delegate_on_absence (내부용, 클라이언트 호출 없음)

trigger와 pg_cron에서만 호출. 관리자용 "지금 재배정" 버튼도 고려할 수 있으나 YAGNI 제외.

---

## 4. Frontend: Routing & Load/Action Signatures

### 4.1 `/t/[tenantSlug]/admin/delegations/+page.server.ts` (신규)

```ts
import { redirect, fail } from '@sveltejs/kit';
import { resolveTenant } from '$lib/server/tenant';
import { getDelegationRulesWithProfiles } from '$lib/server/queries/delegations';

export const load = async ({ locals, params }) => {
  const { supabase } = locals;
  const tenant = await resolveTenant(supabase, params.tenantSlug);
  if (!tenant.isOwnerOrAdmin) throw redirect(302, `/t/${params.tenantSlug}/approval/inbox`);

  const rules = await getDelegationRulesWithProfiles(supabase, tenant.id);
  return { tenant, rules };
};

export const actions = {
  delete: async ({ locals, request, params }) => {
    const { supabase } = locals;
    const tenant = await resolveTenant(supabase, params.tenantSlug);
    const form = await request.formData();
    const id = form.get('id') as string;

    const { error } = await supabase
      .from('delegation_rules')
      .delete()
      .eq('id', id)
      .eq('tenant_id', tenant.id);

    if (error) return fail(400, { message: error.message });
    return { success: true };
  }
};
```

### 4.2 `/t/[tenantSlug]/admin/delegations/new/+page.server.ts`

```ts
import { delegationRuleSchema } from '$lib/server/schemas/delegationRule';
import { zodErrors, formError } from '$lib/forms';

export const load = async ({ locals, params }) => {
  const { supabase } = locals;
  const tenant = await resolveTenant(supabase, params.tenantSlug);
  if (!tenant.isOwnerOrAdmin) throw redirect(302, '..');

  const members = await getMembersWithProfiles(supabase, tenant.id);
  const forms = await supabase.from('approval_forms').select('id, code, name').eq('tenant_id', tenant.id);
  return { tenant, members, forms: forms.data ?? [] };
};

export const actions = {
  create: async ({ locals, request, params }) => {
    const { supabase } = locals;
    const tenant = await resolveTenant(supabase, params.tenantSlug);

    const form = await request.formData();
    const parsed = delegationRuleSchema.safeParse({
      delegator_user_id: form.get('delegator_user_id'),
      delegate_user_id: form.get('delegate_user_id'),
      form_id: form.get('form_id') || null,
      amount_limit: form.get('amount_limit') ? Number(form.get('amount_limit')) : null,
      effective_from: form.get('effective_from'),
      effective_to: form.get('effective_to') || null
    });

    if (!parsed.success) return fail(400, { errors: zodErrors(parsed.error) });

    const { error } = await supabase.from('delegation_rules').insert({
      ...parsed.data,
      tenant_id: tenant.id,
      created_by: (await supabase.auth.getUser()).data.user!.id
    });

    if (error) return fail(400, { errors: formError(error.message) });
    throw redirect(303, `/t/${params.tenantSlug}/admin/delegations`);
  }
};
```

### 4.3 `/t/[tenantSlug]/admin/absences/+page.server.ts`

동일 패턴 (멤버 전원 부재 관리, owner/admin only).

### 4.4 `/t/[tenantSlug]/my/absences/+page.server.ts` (self-service)

```ts
export const load = async ({ locals, params }) => {
  const { supabase } = locals;
  const tenant = await resolveTenant(supabase, params.tenantSlug);

  const { data: absences } = await supabase
    .from('user_absences')
    .select('*, delegate:delegate_user_id(id), scope_form:scope_form_id(id, code, name)')
    .eq('tenant_id', tenant.id)
    .order('start_at', { ascending: false });

  // RLS로 본인 것만 반환됨. 별도 .eq('user_id') 불필요하지만 명시 가능.
  const members = await getMembersWithProfiles(supabase, tenant.id); // delegate picker용

  return { tenant, absences: absences ?? [], members };
};

export const actions = {
  create: async ({ locals, request, params }) => {
    const { supabase } = locals;
    const tenant = await resolveTenant(supabase, params.tenantSlug);
    const form = await request.formData();
    const parsed = absenceSchema.safeParse({
      delegate_user_id: form.get('delegate_user_id'),
      absence_type: form.get('absence_type'),
      scope_form_id: form.get('scope_form_id') || null,
      start_at: form.get('start_at'),
      end_at: form.get('end_at'),
      reason: form.get('reason') || null
    });
    if (!parsed.success) return fail(400, { errors: zodErrors(parsed.error) });

    const { error } = await supabase.from('user_absences').insert({
      ...parsed.data,
      tenant_id: tenant.id,
      user_id: (await supabase.auth.getUser()).data.user!.id
    });

    if (error) return fail(400, { errors: formError(error.message) });
    return { success: true };
  },
  // update, delete 동일 패턴
};
```

### 4.5 `drafts/new/[formCode]/+page.svelte` (변경)

기존 UI에 "후결로 기안" 토글 + `reason` textarea 추가. Submit 시 `is_post_facto` state에 따라 server action이 RPC 분기.

```svelte
<!-- 간단 스니펫 -->
<label>
  <input type="checkbox" bind:checked={isPostFacto} />
  후결로 기안 (사후결재)
</label>

{#if isPostFacto}
  <label>
    사유 (필수)
    <textarea bind:value={postFactoReason} required />
  </label>
{/if}

<form method="POST" action="?/submit" use:enhance={({ formData }) => {
  formData.set('is_post_facto', String(isPostFacto));
  formData.set('post_facto_reason', postFactoReason);
  formData.set('approver_line', JSON.stringify(approverLine));
}}>
  <!-- ... -->
</form>
```

서버 액션:

```ts
submit: async ({ locals, request, params }) => {
  const form = await request.formData();
  const isPostFacto = form.get('is_post_facto') === 'true';
  // ...
  if (isPostFacto) {
    const reason = form.get('post_facto_reason') as string;
    const { data, error } = await supabase.rpc('fn_submit_post_facto', {
      p_form_id, p_title, p_data, p_approver_line, p_reason: reason
    });
    // ...
  } else {
    const { data, error } = await supabase.rpc('fn_submit_draft', { ... });
  }
}
```

---

## 5. Zod Schemas

파일: `src/lib/server/schemas/delegationRule.ts`

```ts
import { z } from 'zod';

export const delegationRuleSchema = z.object({
  delegator_user_id: z.string().uuid(),
  delegate_user_id: z.string().uuid(),
  form_id: z.string().uuid().nullable(),
  amount_limit: z.number().nonnegative().nullable(),
  effective_from: z.coerce.date(),
  effective_to: z.coerce.date().nullable()
}).refine(d => d.delegator_user_id !== d.delegate_user_id, {
  message: '위임자와 대리인은 달라야 합니다',
  path: ['delegate_user_id']
}).refine(d => !d.effective_to || d.effective_to > d.effective_from, {
  message: '종료일은 시작일 이후여야 합니다',
  path: ['effective_to']
});

export type DelegationRuleInput = z.infer<typeof delegationRuleSchema>;
```

파일: `src/lib/server/schemas/absence.ts`

```ts
import { z } from 'zod';

export const absenceSchema = z.object({
  delegate_user_id: z.string().uuid(),
  absence_type: z.enum(['annual', 'sick', 'business_trip', 'other']),
  scope_form_id: z.string().uuid().nullable(),
  start_at: z.coerce.date(),
  end_at: z.coerce.date(),
  reason: z.string().max(500).nullable()
}).refine(d => d.end_at > d.start_at, {
  message: '종료일시는 시작일시 이후여야 합니다',
  path: ['end_at']
});

export type AbsenceInput = z.infer<typeof absenceSchema>;
```

파일: `src/lib/server/schemas/postFactoSubmit.ts`

```ts
import { z } from 'zod';
export const postFactoSubmitSchema = z.object({
  is_post_facto: z.boolean(),
  post_facto_reason: z.string().min(1, '사유는 필수입니다').max(1000)
}).refine(d => !d.is_post_facto || d.post_facto_reason.trim().length > 0, {
  message: '후결 기안 시 사유는 필수입니다',
  path: ['post_facto_reason']
});
```

---

## 6. Svelte 5 Components

### 6.1 ApprovalLine.svelte (변경)

**변경 사항**: 스텝별 배지 (대리/전결/후결) 렌더링 추가.

```svelte
<script lang="ts">
  import type { ApprovalStep, DocumentStatus } from '$lib/types/approval';

  let { steps, docStatus }: { steps: ApprovalStep[]; docStatus: DocumentStatus } = $props();

  function stepBadge(step: ApprovalStep): { label: string; color: string } | null {
    if (step.status === 'skipped' && step.delegated) return { label: '전결', color: 'purple' };
    if (step.acted_by_proxy_user_id) return { label: '대리', color: 'orange' };
    return null;
  }

  const isPostFacto = $derived(docStatus === 'pending_post_facto');
</script>

{#if isPostFacto}
  <div class="post-facto-badge">후결 진행 중</div>
{/if}

<ol class="approval-line">
  {#each steps as step (step.id)}
    <li class="step status-{step.status}">
      <span class="approver">{step.approver_name}</span>
      {#if stepBadge(step)}
        {@const badge = stepBadge(step)}
        <span class="badge badge-{badge.color}">{badge.label}</span>
      {/if}
      {#if step.acted_by_proxy_user_id}
        <small class="proxy-hint">by {step.proxy_name}</small>
      {/if}
    </li>
  {/each}
</ol>
```

`step.delegated`는 audit_logs 조인으로 계산한 derived field (서버 load에서 주입).

### 6.2 ApprovalPanel.svelte (변경)

**변경 사항**: active absence 감지 시 "대리 승인" 라벨.

```svelte
<script lang="ts">
  let {
    step,
    currentUserId,
    activeProxyFor  // 서버에서 주입: 이 유저가 대리 가능한 user_id[]
  }: {
    step: ApprovalStep;
    currentUserId: string;
    activeProxyFor: string[];
  } = $props();

  const isOwnApproval = $derived(step.approver_user_id === currentUserId);
  const canProxy = $derived(!isOwnApproval && activeProxyFor.includes(step.approver_user_id));
  const label = $derived(isOwnApproval ? '승인' : canProxy ? '대리 승인' : null);
</script>

{#if label}
  <form method="POST" action="?/approve" use:enhance>
    <input type="hidden" name="step_id" value={step.id} />
    <textarea name="comment" placeholder="의견 (선택)"></textarea>
    <button type="submit">{label}</button>
  </form>
{/if}
```

서버 load에서 `activeProxyFor` 계산:

```ts
// src/routes/t/[tenantSlug]/approval/documents/[id]/+page.server.ts
const { data: absences } = await supabase
  .from('user_absences')
  .select('user_id')
  .eq('delegate_user_id', currentUserId)
  .lte('start_at', new Date().toISOString())
  .gte('end_at', new Date().toISOString());

const activeProxyFor = absences?.map(a => a.user_id) ?? [];
```

### 6.3 DelegationRuleForm.svelte (신규)

`/admin/delegations/new` + `/admin/delegations/[id]` 공용. FormErrors 패턴.

### 6.4 AbsenceForm.svelte (신규)

`/admin/absences/new` + `/my/absences` 공용.

### 6.5 Svelte 5 규칙 체크리스트

- [x] `$state`, `$props`, `$derived` runes 사용
- [x] Actions에 `parent()` 없음 — `resolveTenant` inline
- [x] 복잡 state (approver_line, members picker)는 `use:enhance`에서 `formData.set`
- [x] FormErrors 공용 타입 사용 (`$lib/forms.ts`)
- [x] `$state(data.x)` 경고 시 `untrack(() => [...data.x])`
- [x] Hidden input은 primitive만

---

## 7. 핵심 알고리즘

### 7.1 Delegation 매칭 우선순위 (fn_submit_draft 내부)

```
INPUT: approver_id, form_id, amount (nullable)

SELECT dr FROM delegation_rules
 WHERE delegator_user_id = approver_id
   AND (form_id = :form_id OR form_id IS NULL)
   AND (amount_limit IS NULL OR amount <= amount_limit)
   AND effective_from <= now()
   AND (effective_to IS NULL OR effective_to > now())
 ORDER BY
   (form_id IS NULL) ASC,     -- (1) 구체 form 우선
   amount_limit ASC NULLS LAST,-- (2) 타이트한 한도 우선 (한도 있는 규칙을 먼저)
   effective_from DESC         -- (3) 최신 규칙 우선
 LIMIT 1

RESULT: 매칭 규칙 1건 or NULL
```

**우선순위 이유**:
- (1) 특정 form 규칙이 전체 form 규칙을 override
- (2) "1천만원 이하 전결"이 "무제한 전결"보다 구체적이며 감사 관점에서 더 안전
- (3) 최신 규칙이 더 최근 정책 반영

### 7.2 Proxy 체크 (fn_approve_step 내부)

```
acting_user := auth.uid()
target_step := SELECT * FROM approval_steps WHERE id = p_step_id FOR UPDATE

IF target_step.approver_user_id = acting_user:
  → 본인 승인 (proxy = NULL)
ELSE:
  absence := fn_find_active_absence(target_step.tenant_id,
                                    target_step.approver_user_id,
                                    doc.form_id)
  IF absence IS NULL → RAISE 'not authorized'
  IF absence.delegate_user_id ≠ acting_user → RAISE 'not authorized'

  # 체인 깊이 제한
  acting_absence := fn_find_active_absence(target_step.tenant_id,
                                           acting_user,
                                           doc.form_id)
  IF acting_absence IS NOT NULL → RAISE 'proxy chain depth exceeded'

  → proxy 승인 (proxy = acting_user)
```

### 7.3 Post-facto 원자성

- RPC 전체가 단일 TX
- form에 `FOR UPDATE` 락 → 스냅샷 일관성
- 실패 지점 어디서든 전체 롤백 (document, steps, audit 모두)
- 사유 검증을 TX 시작 직후 수행 (불필요한 락 시간 최소화)

### 7.4 부재 자동 전환 (Trigger)

```
TRIGGER AFTER INSERT OR UPDATE OF (delegate_user_id, start_at, end_at, scope_form_id)
  ON user_absences
  FOR EACH ROW:

  IF NEW.start_at <= now() < NEW.end_at:
    fn_auto_delegate_on_absence(NEW.id)
```

**Idempotency**:
- UPDATE 시 WHERE `approver_user_id = v_absence.user_id` → 이미 대리인으로 재배정된 행은 매칭 안 됨
- cron은 매일 00:00 활성 absence 전체에 대해 동일 함수 호출 → 이미 반영된 건은 자연 스킵

---

## 8. pg_cron 운영 고려

### 8.1 배경
- v1.1이 Rigel의 **첫 pg_cron 사용**
- Supabase local (`http://127.0.0.1:54321`) 및 cloud 모두 `pg_cron` 확장 지원

### 8.2 설정 방식

```sql
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

SELECT cron.schedule(
  'absence-auto-delegate-daily-backup',
  '0 15 * * *',  -- UTC 15:00 = KST 00:00
  $$ SELECT fn_auto_delegate_on_absence(id)
       FROM user_absences
      WHERE now() BETWEEN start_at AND end_at $$
);
```

### 8.3 운영 체크리스트
- Supabase local에서 `pg_cron` extension 사전 활성화 확인 (`supabase/config.toml`의 `extensions` 섹션)
- `cron.job_run_details` 테이블에서 실행 이력 확인 (Supabase Studio)
- 시간대: pg_cron은 UTC 기준 → KST 00:00 = UTC 15:00 (전날)
- Unschedule은 `SELECT cron.unschedule('absence-auto-delegate-daily-backup')`

---

## 9. Smoke Test Specs (+15)

### 9.1 M11 전결 (S26~S29)

| # | 시나리오 | Setup | Execute | Expected |
|---|---|---|---|---|
| S26 | 금액 매칭 전결 | form meta amount_field='amount'; rule amount_limit=1000000, delegate=B; approver=A | fn_submit_draft with amount=500000 | A step status=skipped, audit 'delegated' w/ rule.id |
| S27 | form-specific 우선 | rule1: form=NULL, delegate=B; rule2: form=doc.form, delegate=C | fn_submit_draft | A step skipped, audit delegated to C (rule2) |
| S28 | effective_to 경과 | rule effective_to < now() | fn_submit_draft | step status=pending (not skipped) |
| S29 | 여러 규칙 충돌 | rule1 amount=∞, rule2 amount=100, amount=50 | fn_submit_draft | rule2 선택 (ORDER BY amount_limit ASC NULLS LAST) |

### 9.2 M12 대결 (S30~S34)

| # | 시나리오 | Setup | Execute | Expected |
|---|---|---|---|---|
| S30 | 활성 absence 대리 승인 | absence: user=A, delegate=B, active | auth.uid=B, fn_approve_step(step A) | success, acted_by_proxy_user_id=B, audit 'approved_by_proxy' |
| S31 | 비활성 absence | absence end_at < now() | auth.uid=B, fn_approve_step(step A) | RAISE 'not authorized' |
| S32 | scope 불일치 | absence scope_form_id=X, doc.form_id=Y | auth.uid=B, fn_approve_step | RAISE 'not authorized' |
| S33 | 체인 깊이 2 | absence1: A→B 활성; absence2: B→C 활성 | auth.uid=C, fn_approve_step(step A) | RAISE 'proxy chain depth exceeded' |
| S34 | 본인 승인 proxy NULL | 일반 승인 | auth.uid=A, fn_approve_step(step A) | acted_by_proxy_user_id IS NULL |

### 9.3 M13 후결 (S35~S37)

| # | 시나리오 | Setup | Execute | Expected |
|---|---|---|---|---|
| S35 | 후결 정상 기안 | form seeded | fn_submit_post_facto(reason='긴급 계약') | doc.status='pending_post_facto', audit 'submitted_post_facto' |
| S36 | 사유 미입력 | | fn_submit_post_facto(reason='') | RAISE 'post-facto reason required' |
| S37 | 후결 승인 완료 | S35 후 정상 fn_approve_step × n | 전체 승인 | doc.status='approved' (pending→approved 정상 전환) |

### 9.4 M14 부재자동 (S38~S40)

| # | 시나리오 | Setup | Execute | Expected |
|---|---|---|---|---|
| S38 | INSERT 시 즉시 재배정 | pending step approver=A | INSERT user_absences(user=A, delegate=B) | trigger fire, step.approver_user_id=B, audit 'auto_delegated' |
| S39 | 멱등성 | S38 후 | fn_auto_delegate_on_absence(absence.id) again | 재배정 count=0 (이미 B) |
| S40 | cron 백업 복구 | 모의 trigger 실패 (step 수동 A로 돌림) | SELECT fn_auto_delegate_on_absence(id) FROM active absences | 누락분 count>0 복구 |

### 9.5 회귀 (v1.0 S1~S25)

- 각 마일스톤 완료 직후 **전체 재실행** 필수
- 특히 S13~S17 (결재 승인/반려/회수 코어)는 proxy 확장이 기존 경로를 깨지 않음을 검증

---

## 10. 프로젝트 의존성

### 10.1 신규 패키지
- **없음** (v1.0 스택 재사용)
- pg_cron은 Supabase 내장

### 10.2 Supabase config 확인
- `supabase/config.toml` — `pg_cron` extension 활성화 확인
- 없다면:
  ```toml
  [db.extensions]
  pg_cron = true
  ```

---

## 11. 환경변수

**v1.1 신규 환경변수 없음** (v1.0 설정 그대로 사용).

---

## 12. 수동 테스트 체크리스트 (Do 단계에서 사용)

### M11
- [ ] 0019~0021 migration apply + advisor 0 WARN
- [ ] Admin UI: delegations CRUD (생성/수정/삭제)
- [ ] S26~S29 통과
- [ ] 기존 S1~S25 회귀 통과

### M12
- [ ] 0022~0024 migration apply + advisor 0 WARN
- [ ] Admin absences CRUD + Self-service /my/absences
- [ ] ApprovalPanel에 "대리 승인" 라벨 정상 표시
- [ ] S30~S34 통과
- [ ] S1~S29 회귀 통과

### M13
- [ ] 0025~0026 migration apply
- [ ] drafts/new 페이지 후결 토글 + 사유 필수
- [ ] S35~S37 통과
- [ ] S1~S34 회귀 통과

### M14
- [ ] 0027~0029 migration apply + pg_cron extension 활성화
- [ ] user_absences INSERT → 즉시 재배정 확인
- [ ] cron.job_run_details에서 00:00 실행 확인 (수동 트리거: `SELECT cron.schedule_in_database(...)`)
- [ ] Inbox 배지 표시
- [ ] S38~S40 통과
- [ ] S1~S37 회귀 통과

---

## 13. Design Complete Criteria

- [x] 모든 migration 0019~0029 SQL 작성
- [x] 모든 RPC pseudocode + signature 확정
- [x] 모든 RLS 정책 SQL 포함 (action별 분리, `(SELECT auth.uid())` 래핑)
- [x] 신규·변경 라우트 Load/Action signature 작성
- [x] Zod schema 3종
- [x] Svelte 5 컴포넌트 변경사항 명시
- [x] Smoke 40개 (v1.0 25 + v1.1 15) 정의
- [x] 핵심 알고리즘 의사코드 (matching, proxy, atomicity, trigger)
- [x] pg_cron 운영 가이드
- [x] Risk Register (§14)

---

## 14. Risk Update (Plan → Design에서 추가 발견)

| # | Risk | 출처 | Mitigation | 마일스톤 |
|---|---|---|---|---|
| R1 | 전결 ↔ 부재 충돌 | Plan | **정책 고정: 부재 > 전결**. fn_submit_draft은 delegation으로 skip, 이후 fn_approve_step은 skipped 스텝을 건드리지 않음 → 자연 배타 | M11/M12 |
| R2 | 후결 원자성 | Plan | 단일 TX + `FOR UPDATE`. 사유 검증을 초입에 배치 | M13 |
| R3 | pg_cron 멱등성 | Plan | UPDATE WHERE approver = absence.user → 이미 재배정된 행 자연 제외 | M14 |
| R4 | audit enum backward compat | Plan | ADD VALUE append only, migration 파일 TX 외부 분리 (0020, 0023b, 0025, 0027) | 전 마일스톤 |
| R5 | 위임 체인 무한 루프 | Plan | fn_approve_step 내부 depth≥2 RAISE | M12 |
| R6 | delegation 우선순위 모호 | Plan | ORDER BY 3단 정렬 (form 구체성 > amount 하한 > 최신) | M11 |
| **R7** | **fn_advance_document 신규 helper 필요** | **Design 발견** | v1.0 fn_approve_step 내부에 있던 "다음 스텝 활성화 / 완료" 로직을 별도 함수 분리. M12에서 proxy 경로도 동일 로직 호출해야 함. | **M12** |
| **R8** | **amount 추출 실패 시 동작** | **Design 발견** | `form.metadata.amount_field`가 없거나 data에 해당 필드 없으면 amount=NULL → amount_limit NULL인 규칙만 매칭 (보수적) | **M11** |
| **R9** | **delegation 체인 전결 금지** | **Design 발견** | delegate_user_id가 또 delegator로 등록돼 있어도 **2차 매칭 안 함** (fn_submit_draft는 final_approver_id 한번만 검사). 설계상 의도: 체인 전결 = 위임 회피 | **M11** |
| **R10** | **pg_cron 시간대** | **Design 발견** | pg_cron은 UTC. KST 00:00 = UTC 15:00 (전날). cron expression `0 15 * * *` 주석 필수 | **M14** |
| **R11** | **Svelte 5 $state stale in admin list** | **Design 발견** | delegations/absences 목록에 `$state(data.rules)` 시 재 방문 시 stale. `untrack(() => [...data.rules])` 패턴 준수 | **M11/M12 UI** |
| **R12** | **user_absences self-service INSERT 차단 우회** | **Design 발견** | RLS `user_id = (SELECT auth.uid())` 강제 (WITH CHECK). 클라이언트가 임의 user_id 지정 불가 | **M12** |
| **R13** | **trigger 재귀 방지** | **Design 발견** | fn_absence_trigger_handler는 user_absences UPDATE 안 함 (approval_steps만 UPDATE). 재귀 없음. 확인만 | **M14** |
| **R14** | **pg_cron 중복 등록** | **Design 발견** | `cron.schedule('name', ...)` 중복 호출 시 에러. migration 0029를 `DROP IF EXISTS` 후 재등록 패턴으로: `SELECT cron.unschedule('absence-auto-delegate-daily-backup') WHERE EXISTS (...)` | **M14** |

---

## 15. References

- **Plan**: [docs/01-plan/features/전자결재-v1.1-korean-exceptions.plan.md](../../01-plan/features/전자결재-v1.1-korean-exceptions.plan.md)
- **v1.0 Design**: [docs/02-design/features/approval-mvp.design.md](./approval-mvp.design.md) (패턴 재사용)
- **v1.0 Analysis**: [docs/03-analysis/approval-mvp.analysis.md](../../03-analysis/approval-mvp.analysis.md)
- **시장 조사**: [docs/01-research/korean-groupware-approval-review.md](../../01-research/korean-groupware-approval-review.md)
- **CLAUDE.md**: 프로젝트 규칙 (RLS/Mutation/Svelte 5/Storage/Auth)
- **Supabase pg_cron**: https://supabase.com/docs/guides/database/extensions/pg_cron

---

## 16. Next Steps

```
/pdca do 전자결재-v1.1-korean-exceptions
```

**Do Phase 착수 순서 (M11부터)**:
1. `supabase/migrations/0019_delegation_rules.sql` 작성 → `apply_migration` → `get_advisors`
2. `0020_audit_action_delegated.sql` (TX 외부) apply
3. `0021_fn_submit_draft_v2.sql` apply + 기존 fn_submit_draft 호출부 회귀 확인
4. `src/lib/server/schemas/delegationRule.ts` + `src/lib/server/queries/delegations.ts`
5. `/admin/delegations/*` 페이지 3개 (list/new/[id])
6. S26~S29 수동 smoke
7. 기존 S1~S25 회귀
8. M11 완료 → M12 착수

**HARD-GATE 유지**: 각 마일스톤 완료 후 사용자 확인을 받기 전에는 다음 마일스톤 migration apply 금지.
