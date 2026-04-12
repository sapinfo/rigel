-- 0046: tenant_members에 admin UPDATE 정책 추가
-- v2.1 M4: 관리자가 멤버의 부서/직급을 배정할 수 있도록
-- 기존: SELECT만 존재 (tm_member_select)

CREATE POLICY tm_admin_update ON public.tenant_members
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));
