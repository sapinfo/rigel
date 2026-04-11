-- 0003_tenant_members.sql
-- 테넌트 멤버십. 사용자-테넌트 N:M + role 부여.
-- helper 함수 is_tenant_member / is_tenant_admin 정의.
-- tenants의 RLS 정책과 profiles의 peer SELECT 정책도 여기서 추가.

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

-- ─── Helper functions (SECURITY DEFINER, STABLE) ──────────
-- 내부에서 RLS를 우회하여 멤버십 조회. RLS 재귀 방지.

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

-- ─── RLS policies using helpers ───────────────────────────

-- tenants: 멤버만 조회 가능
CREATE POLICY tenants_member_select ON public.tenants
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(id));

-- tenant_members: 같은 테넌트의 멤버들은 서로 보임
CREATE POLICY tm_member_select ON public.tenant_members
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

-- profiles: 같은 테넌트 멤버는 서로 프로필 조회 가능 (결재선 표시 목적)
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
