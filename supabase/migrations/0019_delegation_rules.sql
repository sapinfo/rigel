-- 0019_delegation_rules.sql
-- v1.1 M11: 전결(Delegation) 규칙 테이블
--
-- 개요:
--   - 관리자가 사전 등록한 "전결 규칙"에 매칭되는 결재 단계는 상신 시점에
--     자동으로 status='skipped'로 처리되고 audit 'delegated'가 기록된다.
--   - 규칙 매칭은 fn_submit_draft 스냅샷 시점에 1회 확정. 이후 규칙 변경은 영향 없음.
--
-- 컬럼 의미:
--   - delegator_user_id: 원래 결재선에 포함된 승인자 (위임자)
--   - delegate_user_id:  전결 수행자 (위임 대상 - 감사 추적용, 스텝 자체는 skip)
--   - form_id:  NULL = 전 양식, NOT NULL = 해당 양식만
--   - amount_limit: NULL = 금액 무관, NOT NULL = content->>'amount'가 이 값 이하일 때만
--   - effective_from/to: 효력기간 (to NULL = 상시)
--
-- RLS (v1.0 규칙 준수):
--   - (SELECT auth.uid()) 래핑 필수
--   - FOR ALL 금지, action별 단일 정책
--   - SELECT: 멤버 전원 (투명성)
--   - INSERT/UPDATE/DELETE: tenant admin만

CREATE TABLE public.delegation_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  delegator_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  delegate_user_id  uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  form_id uuid NULL REFERENCES public.approval_forms(id) ON DELETE CASCADE,
  amount_limit numeric(14,2) NULL,
  effective_from timestamptz NOT NULL DEFAULT now(),
  effective_to   timestamptz NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  CONSTRAINT delegation_rules_self_check CHECK (delegator_user_id <> delegate_user_id),
  CONSTRAINT delegation_rules_range_check CHECK (
    effective_to IS NULL OR effective_to > effective_from
  ),
  CONSTRAINT delegation_rules_amount_check CHECK (
    amount_limit IS NULL OR amount_limit >= 0
  )
);

CREATE INDEX dr_lookup_idx
  ON public.delegation_rules (tenant_id, delegator_user_id, form_id, effective_from DESC);

CREATE INDEX dr_tenant_idx
  ON public.delegation_rules (tenant_id);

CREATE INDEX dr_delegate_idx
  ON public.delegation_rules (tenant_id, delegate_user_id);

COMMENT ON TABLE public.delegation_rules IS
  'v1.1 Delegation (전결) rules. Matched at fn_submit_draft snapshot time.';

ALTER TABLE public.delegation_rules ENABLE ROW LEVEL SECURITY;

-- SELECT: 테넌트 멤버 전원 (전결 규칙은 투명하게 공개)
CREATE POLICY dr_select ON public.delegation_rules
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

-- INSERT: 관리자만. created_by는 현재 사용자로 강제.
CREATE POLICY dr_admin_insert ON public.delegation_rules
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_tenant_admin(tenant_id)
    AND created_by = (SELECT auth.uid())
  );

-- UPDATE: 관리자만
CREATE POLICY dr_admin_update ON public.delegation_rules
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

-- DELETE: 관리자만
CREATE POLICY dr_admin_delete ON public.delegation_rules
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));
