-- 0024_fn_approve_with_proxy.sql
-- v1.1 M12: fn_approve_step 교체 — 대리(proxy) 승인 지원.
--
-- v1.0 대비 변경점:
--   1. acting_user가 current step의 본인이 아닐 때, 활성 user_absence를 조회
--   2. scope_form_id 매칭 (NULL=전체 대리, 또는 doc.form_id=scope_form_id)
--   3. 대리인이면 승인 허용. acted_by_proxy_user_id 기록 + audit 'approved_by_proxy'
--   4. 체인 깊이 제한: acting_user도 부재 중이면 RAISE (depth>=2 차단)
--
-- Helper fn_find_active_absence(tenant, user, form) → user_absences row (또는 NULL)
-- STABLE SECURITY DEFINER로 RLS 우회 필요 (부재 체크 시 대리인이 원 approver의 absence를 조회)
--
-- 시그니처는 v1.0 동일: fn_approve_step(p_document_id, p_comment)

CREATE OR REPLACE FUNCTION public.fn_find_active_absence(
  p_tenant_id uuid,
  p_user_id uuid,
  p_form_id uuid
)
RETURNS public.user_absences
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT a.*
    FROM public.user_absences a
   WHERE a.tenant_id = p_tenant_id
     AND a.user_id = p_user_id
     AND now() BETWEEN a.start_at AND a.end_at
     AND (a.scope_form_id IS NULL OR a.scope_form_id = p_form_id)
   ORDER BY a.start_at DESC
   LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.fn_find_active_absence(uuid, uuid, uuid) TO authenticated;

-- fn_approve_step 재정의
CREATE OR REPLACE FUNCTION public.fn_approve_step(
  p_document_id uuid,
  p_comment text DEFAULT NULL
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
  v_step public.approval_steps;
  v_next_step public.approval_steps;
  v_absence public.user_absences;
  v_acting_absence public.user_absences;
  v_proxy uuid := NULL;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- 문서 잠금
  SELECT * INTO v_doc
  FROM public.approval_documents
  WHERE id = p_document_id
  FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found' USING ERRCODE = '02000';
  END IF;

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Document not in progress' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  -- 현재 step 잠금 + 기본 검증 (v1.0 동일)
  SELECT * INTO v_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND step_index = v_doc.current_step_index
  FOR UPDATE;

  IF v_step.id IS NULL THEN
    RAISE EXCEPTION 'Current step not found' USING ERRCODE = '02000';
  END IF;

  IF v_step.status <> 'pending' THEN
    RAISE EXCEPTION 'Step not pending' USING ERRCODE = '22023';
  END IF;

  IF v_step.step_type <> 'approval' THEN
    RAISE EXCEPTION 'Cannot approve a reference step' USING ERRCODE = '22023';
  END IF;

  -- v1.1: 권한 분기
  IF v_step.approver_user_id = v_user_id THEN
    -- 본인 직접 승인 (v1.0 경로)
    v_proxy := NULL;
  ELSE
    -- Proxy 경로: 해당 approver의 활성 absence 확인
    v_absence := public.fn_find_active_absence(
      v_doc.tenant_id,
      v_step.approver_user_id,
      v_doc.form_id
    );

    IF v_absence.id IS NULL THEN
      RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
    END IF;

    IF v_absence.delegate_user_id <> v_user_id THEN
      RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
    END IF;

    -- 체인 깊이 제한: acting_user 자신도 absence면 거부 (depth>=2)
    v_acting_absence := public.fn_find_active_absence(
      v_doc.tenant_id,
      v_user_id,
      v_doc.form_id
    );
    IF v_acting_absence.id IS NOT NULL THEN
      RAISE EXCEPTION 'Proxy chain depth exceeded' USING ERRCODE = '22023';
    END IF;

    v_proxy := v_user_id;
  END IF;

  -- 승인 처리
  UPDATE public.approval_steps
  SET status = 'approved',
      acted_at = now(),
      comment = p_comment,
      acted_by_proxy_user_id = v_proxy
  WHERE id = v_step.id;

  -- 다음 approval step 찾기 (reference step은 건너뜀)
  SELECT * INTO v_next_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND step_index > v_doc.current_step_index
    AND step_type = 'approval'
    AND status = 'pending'
  ORDER BY step_index ASC
  LIMIT 1;

  IF v_next_step.id IS NULL THEN
    -- 마지막 결재 단계였음 → 완료
    -- Risk #13: 남은 pending reference step들을 skipped로 일괄 처리
    UPDATE public.approval_steps
    SET status = 'skipped'
    WHERE document_id = p_document_id
      AND status = 'pending';

    UPDATE public.approval_documents
    SET status = 'completed',
        completed_at = now(),
        updated_at = now()
    WHERE id = p_document_id
    RETURNING * INTO v_doc;
  ELSE
    UPDATE public.approval_documents
    SET current_step_index = v_next_step.step_index,
        updated_at = now()
    WHERE id = p_document_id
    RETURNING * INTO v_doc;
  END IF;

  -- 감사 로그 (action: approve vs approved_by_proxy)
  -- NOTE: CASE 결과를 명시적으로 audit_action으로 캐스트해야 함.
  -- 그렇지 않으면 CASE 결과 타입이 text로 해결되어 enum 컬럼 INSERT 시
  -- "column action is of type audit_action but expression is of type text" 발생.
  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload, acted_by_proxy_user_id
  ) VALUES (
    v_doc.tenant_id, v_doc.id,
    COALESCE(v_proxy, v_user_id),
    (CASE WHEN v_proxy IS NULL THEN 'approve' ELSE 'approved_by_proxy' END)::public.audit_action,
    jsonb_build_object(
      'step_index', v_step.step_index,
      'comment', p_comment,
      'original_approver', v_step.approver_user_id
    ),
    v_proxy
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_approve_step(uuid, text) TO authenticated;
