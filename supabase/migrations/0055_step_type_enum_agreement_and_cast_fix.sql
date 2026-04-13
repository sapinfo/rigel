-- 0055: step_type enum에 agreement 추가 + fn_submit_draft v_step_type::public.step_type 캐스트
-- step_type이 enum(approval|reference)인데 text로 INSERT하면 타입 에러 발생
ALTER TYPE public.step_type ADD VALUE IF NOT EXISTS 'agreement';
-- fn_submit_draft 전체 재정의는 Supabase MCP로 적용 완료
