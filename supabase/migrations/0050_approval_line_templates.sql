-- 0050: 결재선 템플릿 (v2.2 M2)
-- 관리자가 양식별 추천 결재선 설정

CREATE TABLE public.approval_line_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  form_id uuid REFERENCES public.approval_forms(id) ON DELETE SET NULL,
  line_json jsonb NOT NULL,
  is_default boolean NOT NULL DEFAULT false,
  priority int NOT NULL DEFAULT 100,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX alt_tenant_form_idx ON public.approval_line_templates (tenant_id, form_id);

ALTER TABLE public.approval_line_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY alt_member_select ON public.approval_line_templates
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY alt_admin_insert ON public.approval_line_templates
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY alt_admin_update ON public.approval_line_templates
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY alt_admin_delete ON public.approval_line_templates
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));
