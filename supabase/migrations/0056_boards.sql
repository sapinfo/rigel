-- 0056_boards.sql
-- 게시판 테이블 + RLS

CREATE TABLE public.boards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  board_type text NOT NULL DEFAULT 'general'
    CHECK (board_type IN ('general', 'department')),
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  sort_order int NOT NULL DEFAULT 0,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX boards_tenant_idx ON public.boards (tenant_id, sort_order);

ALTER TABLE public.boards ENABLE ROW LEVEL SECURITY;

-- SELECT: 테넌트 멤버 + (general OR 본인 부서)
CREATE POLICY boards_select ON public.boards
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      board_type = 'general'
      OR department_id IN (
        SELECT ud.department_id FROM public.user_departments ud
        WHERE ud.user_id = (SELECT auth.uid()) AND ud.tenant_id = boards.tenant_id
      )
    )
  );

CREATE POLICY boards_insert ON public.boards
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY boards_update ON public.boards
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY boards_delete ON public.boards
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));
