-- 0028_fn_auto_delegate_on_absence.sql
-- v1.1 M14: 부재 등록/수정 시점에 해당 사용자의 pending step을 대리인으로 재배정.
--
-- 호출 경로:
--   1. user_absences AFTER INSERT/UPDATE trigger (즉시 반영) — 0029
--   2. pg_cron 매일 00:00 KST (UTC 15:00) 백업 (누락 복구) — 0030
--
-- 동작:
--   - 인자 absence가 활성 기간 내인지 확인 (아니면 no-op, return 0)
--   - approval_steps 중 아래 조건을 모두 만족하는 행 SELECT FOR UPDATE
--     (a) status = 'pending'
--     (b) step_type = 'approval' (reference step은 영향 없음)
--     (c) approver_user_id = absence.user_id
--     (d) tenant_id 일치
--     (e) doc.form_id = absence.scope_form_id (NULL 이면 모든 form)
--   - approver_user_id를 absence.delegate_user_id로 UPDATE
--   - 각 변경 step에 audit 'auto_delegated' 기록
--     payload: {step_index, original_approver, delegate_to, absence_id, source}
--   - 재배정된 step 수를 RETURN
--
-- 멱등성:
--   - WHERE 절이 approver_user_id = absence.user_id 이므로 이미 재배정된 행은 자연 제외
--   - cron 백업이 trigger와 중복 실행되어도 추가 변경 없음

CREATE OR REPLACE FUNCTION public.fn_auto_delegate_on_absence(
  p_absence_id uuid
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_absence public.user_absences;
  v_step record;
  v_reassigned int := 0;
BEGIN
  SELECT * INTO v_absence FROM public.user_absences WHERE id = p_absence_id;
  IF v_absence.id IS NULL THEN
    RAISE EXCEPTION 'Absence not found' USING ERRCODE = '02000';
  END IF;

  -- 활성 기간 외면 no-op
  IF NOT (now() BETWEEN v_absence.start_at AND v_absence.end_at) THEN
    RETURN 0;
  END IF;

  -- pending approval steps 재배정
  -- doc.form_id 비교를 위해 join 필요. SELECT FOR UPDATE로 동시성 방어.
  FOR v_step IN
    SELECT s.id, s.step_index, s.document_id, s.tenant_id
      FROM public.approval_steps s
      JOIN public.approval_documents d ON d.id = s.document_id
     WHERE s.tenant_id = v_absence.tenant_id
       AND s.status = 'pending'
       AND s.step_type = 'approval'
       AND s.approver_user_id = v_absence.user_id
       AND (v_absence.scope_form_id IS NULL OR d.form_id = v_absence.scope_form_id)
       FOR UPDATE OF s
  LOOP
    UPDATE public.approval_steps
       SET approver_user_id = v_absence.delegate_user_id
     WHERE id = v_step.id;

    INSERT INTO public.approval_audit_logs (
      tenant_id, document_id, actor_id, action, payload
    ) VALUES (
      v_step.tenant_id, v_step.document_id, v_absence.user_id, 'auto_delegated',
      jsonb_build_object(
        'step_index', v_step.step_index,
        'original_approver', v_absence.user_id,
        'delegate_to', v_absence.delegate_user_id,
        'absence_id', v_absence.id,
        'scope_form_id', v_absence.scope_form_id
      )
    );

    v_reassigned := v_reassigned + 1;
  END LOOP;

  RETURN v_reassigned;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_auto_delegate_on_absence(uuid) TO authenticated;
