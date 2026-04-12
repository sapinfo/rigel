-- 0023b_audit_action_proxy.sql
-- v1.1 M12: audit_action enum에 'approved_by_proxy' 값 추가.
-- fn_approve_step의 proxy 경로에서 기록.

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'approved_by_proxy';
