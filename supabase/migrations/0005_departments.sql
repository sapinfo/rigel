-- 0005_departments.sql
-- 조직도. 부서 + 사용자-부서 매핑.
-- tenant_members.department_id FK 역추가.

CREATE TABLE public.departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  parent_id uuid REFERENCES public.departments(id) ON DELETE CASCADE,
  name text NOT NULL,
  path text NOT NULL,          -- materialized path (e.g. "/hq/eng/platform")
  sort_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX departments_tenant_idx ON public.departments (tenant_id);
CREATE INDEX departments_parent_idx ON public.departments (parent_id);

-- 겸직 지원용 사용자-부서 N:M
CREATE TABLE public.user_departments (
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  department_id uuid NOT NULL REFERENCES public.departments(id) ON DELETE CASCADE,
  is_primary boolean NOT NULL DEFAULT false,
  PRIMARY KEY (tenant_id, user_id, department_id)
);

-- tenant_members.department_id FK (primary dept의 편의 캐시)
ALTER TABLE public.tenant_members
  ADD CONSTRAINT tm_department_fk
  FOREIGN KEY (department_id) REFERENCES public.departments(id) ON DELETE SET NULL;

ALTER TABLE public.departments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_departments ENABLE ROW LEVEL SECURITY;

-- 멤버는 조회, 관리자만 수정
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
