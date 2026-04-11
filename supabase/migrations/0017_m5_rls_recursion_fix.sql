-- 0017_m5_rls_recursion_fix.sql
-- M5 smoke test에서 발견된 RLS 무한 재귀 해결.
--
-- 원인:
--   ad_select 정책이 approval_steps에 대한 EXISTS를 포함
--   as_select/aal_select/att_select 정책이 approval_documents에 대한 EXISTS를 포함
--   → 서로의 RLS를 trigger하며 무한 재귀
--
-- 해결:
--   SECURITY DEFINER helper 함수로 우회 (함수 내부 쿼리는 RLS 우회됨).
--   drafter/approver 체크 함수 2개 추가.

-- ─── Helper functions (SECURITY DEFINER, STABLE) ───

CREATE OR REPLACE FUNCTION public.is_document_drafter(p_document_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.approval_documents
    WHERE id = p_document_id AND drafter_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.is_document_approver(p_document_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.approval_steps
    WHERE document_id = p_document_id AND approver_user_id = auth.uid()
  );
$$;

-- 문서의 tenant_id를 꺼내는 헬퍼 (is_tenant_member 호출 전 필요)
CREATE OR REPLACE FUNCTION public.get_document_tenant(p_document_id uuid)
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT tenant_id FROM public.approval_documents WHERE id = p_document_id;
$$;

-- ─── Rewrite policies using helpers ────────────────

-- approval_documents.ad_select
DROP POLICY ad_select ON public.approval_documents;
CREATE POLICY ad_select ON public.approval_documents
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      drafter_id = (SELECT auth.uid())
      OR public.is_tenant_admin(tenant_id)
      OR public.is_document_approver(id)
    )
  );

-- approval_steps.as_select
DROP POLICY as_select ON public.approval_steps;
CREATE POLICY as_select ON public.approval_steps
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      approver_user_id = (SELECT auth.uid())
      OR public.is_tenant_admin(tenant_id)
      OR public.is_document_drafter(document_id)
      OR public.is_document_approver(document_id)
    )
  );

-- approval_audit_logs.aal_select
DROP POLICY aal_select ON public.approval_audit_logs;
CREATE POLICY aal_select ON public.approval_audit_logs
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      actor_id = (SELECT auth.uid())
      OR public.is_tenant_admin(tenant_id)
      OR public.is_document_drafter(document_id)
      OR public.is_document_approver(document_id)
    )
  );

-- approval_attachments.att_select
DROP POLICY att_select ON public.approval_attachments;
CREATE POLICY att_select ON public.approval_attachments
  FOR SELECT TO authenticated
  USING (
    uploaded_by = (SELECT auth.uid())
    OR (
      document_id IS NOT NULL
      AND public.is_tenant_member(tenant_id)
      AND (
        public.is_tenant_admin(tenant_id)
        OR public.is_document_drafter(document_id)
        OR public.is_document_approver(document_id)
      )
    )
  );
