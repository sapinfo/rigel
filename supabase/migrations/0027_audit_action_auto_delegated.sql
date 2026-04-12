-- 0027_audit_action_auto_delegated.sql
-- v1.1 M14: audit_action enum에 'auto_delegated' 값 추가.
-- fn_auto_delegate_on_absence가 trigger 또는 cron에서 호출되어 step.approver_user_id를
-- 자동 재배정한 시점에 기록.

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'auto_delegated';
