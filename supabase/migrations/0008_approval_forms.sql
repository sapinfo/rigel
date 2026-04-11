-- 0008_approval_forms.sql
-- 결재 양식. tenant_id NULL = 시스템 양식(복사 원본), NOT NULL = 테넌트 고유.
-- M2 규칙 적용: (SELECT auth.uid()) 래핑 + FOR ALL 금지 + action별 정책 분리.

CREATE TABLE public.approval_forms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid REFERENCES public.tenants(id) ON DELETE CASCADE,  -- NULL = 시스템 양식
  code text NOT NULL,                                              -- e.g. 'leave-request'
  name text NOT NULL,
  description text,
  schema jsonb NOT NULL,                                           -- FormSchema JSONB
  default_approval_line jsonb NOT NULL DEFAULT '[]'::jsonb,        -- ApprovalLineItem[]
  version int NOT NULL DEFAULT 1,
  is_published boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, code)
);

CREATE INDEX approval_forms_tenant_idx ON public.approval_forms (tenant_id);

ALTER TABLE public.approval_forms ENABLE ROW LEVEL SECURITY;

-- ─── RLS (M2 규칙 준수) ──────────────────────────────

-- 시스템 양식(tenant_id IS NULL)은 모든 인증 사용자가 조회 가능
-- (fn_copy_system_forms 복사 참조용)
CREATE POLICY af_system_select ON public.approval_forms
  FOR SELECT TO authenticated
  USING (tenant_id IS NULL);

-- 테넌트 양식: 멤버만 조회
CREATE POLICY af_tenant_select ON public.approval_forms
  FOR SELECT TO authenticated
  USING (tenant_id IS NOT NULL AND public.is_tenant_member(tenant_id));

-- 관리자만 쓰기 (action별 분리)
CREATE POLICY af_admin_insert ON public.approval_forms
  FOR INSERT TO authenticated
  WITH CHECK (tenant_id IS NOT NULL AND public.is_tenant_admin(tenant_id));

CREATE POLICY af_admin_update ON public.approval_forms
  FOR UPDATE TO authenticated
  USING (tenant_id IS NOT NULL AND public.is_tenant_admin(tenant_id))
  WITH CHECK (tenant_id IS NOT NULL AND public.is_tenant_admin(tenant_id));

CREATE POLICY af_admin_delete ON public.approval_forms
  FOR DELETE TO authenticated
  USING (tenant_id IS NOT NULL AND public.is_tenant_admin(tenant_id));
