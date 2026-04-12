-- 0052b: audit_action enum에 agreed/disagreed 추가
-- TX 외부에서 실행 (PG 12+ 규칙: ALTER TYPE ADD VALUE는 TX 내부 사용 불가)

ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'agreed';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'disagreed';
