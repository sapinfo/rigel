-- 0049: 결재선 즐겨찾기 (v2.2 M1)
-- 사용자별 자주 쓰는 결재선 저장

CREATE TABLE public.approval_line_favorites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  form_id uuid REFERENCES public.approval_forms(id) ON DELETE SET NULL,
  line_json jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX alf_user_idx ON public.approval_line_favorites (tenant_id, user_id);

ALTER TABLE public.approval_line_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY alf_owner_select ON public.approval_line_favorites
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY alf_owner_insert ON public.approval_line_favorites
  FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()) AND public.is_tenant_member(tenant_id));

CREATE POLICY alf_owner_delete ON public.approval_line_favorites
  FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));
