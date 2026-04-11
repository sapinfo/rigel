-- 0018_m8_invite_lookup_rpc.sql
-- M8 hotfix: 초대 페이지에서 비멤버(및 비로그인)도 토큰으로 초대 조회 가능해야 함.
-- tenant_invitations의 RLS는 admin 전용이므로 SECURITY DEFINER RPC로 우회.
-- 반환 컬럼은 공개 가능한 범위만 포함 (invited_by, accepted_by 등 제외).

CREATE OR REPLACE FUNCTION public.fn_get_invitation_by_token(p_token uuid)
RETURNS TABLE (
  invitation_id uuid,
  email text,
  role public.tenant_role,
  expires_at timestamptz,
  accepted_at timestamptz,
  tenant_id uuid,
  tenant_slug text,
  tenant_name text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    i.id AS invitation_id,
    i.email,
    i.role,
    i.expires_at,
    i.accepted_at,
    t.id AS tenant_id,
    t.slug AS tenant_slug,
    t.name AS tenant_name
  FROM public.tenant_invitations i
  JOIN public.tenants t ON t.id = i.tenant_id
  WHERE i.token = p_token;
$$;

-- 비로그인 상태에서도 조회 가능해야 하므로 anon 에도 grant
GRANT EXECUTE ON FUNCTION public.fn_get_invitation_by_token(uuid) TO anon, authenticated;
