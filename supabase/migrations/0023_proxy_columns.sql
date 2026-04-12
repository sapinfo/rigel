-- 0023_proxy_columns.sql
-- v1.1 M12: approval_steps / approval_audit_logs에 대리 수행자 컬럼 추가.
--
-- acted_by_proxy_user_id:
--   NULL → 본인이 직접 수행 (기본)
--   NOT NULL → 해당 값이 실제 action을 수행한 대리인

ALTER TABLE public.approval_steps
  ADD COLUMN acted_by_proxy_user_id uuid NULL REFERENCES auth.users(id) ON DELETE RESTRICT;

ALTER TABLE public.approval_audit_logs
  ADD COLUMN acted_by_proxy_user_id uuid NULL REFERENCES auth.users(id) ON DELETE RESTRICT;

COMMENT ON COLUMN public.approval_steps.acted_by_proxy_user_id IS
  'v1.1: Non-null when the step was actioned by an absence proxy.';
COMMENT ON COLUMN public.approval_audit_logs.acted_by_proxy_user_id IS
  'v1.1: Non-null when the audit action was performed by a proxy on behalf of the original approver.';
