-- 0015_m4_linter_fixes.sql
-- Supabase advisor 경고 해결:
--   (1) doc_number_sequences: RLS 활성화되어 있지만 정책 없음 → 명시적 deny-all
--   (2) approval_forms: af_system_select + af_tenant_select 중복 → 하나로 통합

-- ─── doc_number_sequences: 명시적 deny ────────────
-- authenticated가 직접 접근하면 안 됨. fn_next_doc_number(SECURITY DEFINER)만 사용.

CREATE POLICY dns_no_direct_access ON public.doc_number_sequences
  FOR ALL TO authenticated
  USING (false)
  WITH CHECK (false);

-- ─── approval_forms: SELECT 정책 통합 ─────────────
-- af_system_select + af_tenant_select → af_select 하나로

DROP POLICY af_system_select ON public.approval_forms;
DROP POLICY af_tenant_select ON public.approval_forms;

CREATE POLICY af_select ON public.approval_forms
  FOR SELECT TO authenticated
  USING (
    tenant_id IS NULL
    OR public.is_tenant_member(tenant_id)
  );
