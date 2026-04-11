-- 0004_tenant_invitations.sql
-- 테넌트 초대 토큰. 수락은 fn_accept_invitation RPC(0012)에서 처리.

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

-- 관리자(owner/admin)만 초대 조회·생성·취소 가능
CREATE POLICY inv_admin_select ON public.tenant_invitations
  FOR SELECT TO authenticated
  USING (public.is_tenant_admin(tenant_id));

CREATE POLICY inv_admin_insert ON public.tenant_invitations
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY inv_admin_delete ON public.tenant_invitations
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));

-- 수락(accept)은 비멤버도 토큰만 있으면 가능해야 하므로
-- RPC(fn_accept_invitation, SECURITY DEFINER)에서 처리 → 일반 RLS는 없음
