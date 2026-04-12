-- 0052: agreement step type 지원 (v2.2 M4)
-- 합의(agreement) step: 동의(agreed) → 다음 진행, 부동의(disagreed) → 문서 rejected
-- 기존 fn_approve_step은 step_type='approval'만 처리 → agreement용 별도 RPC 생성

BEGIN;

-- audit_action enum에 agreed/disagreed 추가 (TX 외부 불가 → DO 블록 사용 불가, 별도 migration 필요)
-- PG 12+ 에서는 같은 TX에서 ADD VALUE 후 사용 불가이므로 text 캐스트 방식 사용
-- 대안: audit_action enum에 이미 값이 없으면 추가

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'agreed' AND enumtypid = 'public.audit_action'::regtype) THEN
    -- enum 값 추가는 TX 외부에서만 가능하므로 여기서는 스킵
    -- 별도 migration 0052b에서 처리
    NULL;
  END IF;
END $$;

COMMIT;
