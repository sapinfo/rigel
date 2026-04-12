-- 0029_absence_trigger.sql
-- v1.1 M14: user_absences AFTER INSERT/UPDATE 트리거.
--
-- 동작:
--   - INSERT: NEW absence가 활성 기간 내면 fn_auto_delegate_on_absence(NEW.id) 호출
--   - UPDATE OF (delegate_user_id, start_at, end_at, scope_form_id):
--     주요 필드 변경 시 동일하게 재배정 시도. 멱등성으로 안전.
--
-- 재귀 방지:
--   - fn_auto_delegate_on_absence는 user_absences 자체를 UPDATE하지 않음
--     (approval_steps + approval_audit_logs만 변경)
--   - 따라서 trigger 재귀 발생 없음.

CREATE OR REPLACE FUNCTION public.fn_absence_trigger_handler()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.start_at <= now() AND NEW.end_at > now() THEN
    PERFORM public.fn_auto_delegate_on_absence(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_absence_auto_delegate
  AFTER INSERT OR UPDATE OF delegate_user_id, start_at, end_at, scope_form_id
  ON public.user_absences
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_absence_trigger_handler();

COMMENT ON TRIGGER trg_absence_auto_delegate ON public.user_absences IS
  'v1.1 M14: 부재 등록/수정 시 즉시 pending step 재배정. 멱등.';
