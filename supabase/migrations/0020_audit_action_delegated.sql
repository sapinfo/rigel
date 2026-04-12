-- 0020_audit_action_delegated.sql
-- v1.1 M11: audit_action enum에 'delegated' 값 추가.
-- fn_submit_draft v2에서 전결 매칭 시 기록.
--
-- NOTE: PG 12+부터 ALTER TYPE ADD VALUE는 트랜잭션 내 실행 가능
--       (단 같은 TX에서 새 값 사용 불가). 본 파일은 단독 실행되므로 안전.

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'delegated';
