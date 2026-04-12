-- 0026_fn_post_facto.sql
-- v1.1 M13: 후결 RPC + 기존 mutation RPC 확장.
--
-- 변경 내용:
--   1. fn_submit_post_facto (신규)
--      - 단일 TX + SELECT form FOR UPDATE (snapshot)
--      - reason NOT NULL 강제 (RPC 내부 검증)
--      - status='pending_post_facto'로 문서 생성
--      - delegation 매칭 (fn_submit_draft와 동일 로직 재사용)
--      - audit 'submitted_post_facto' 기록 (payload에 reason)
--
--   2. fn_approve_step / fn_reject_step / fn_withdraw_document
--      - status 체크를 'in_progress' → ('in_progress', 'pending_post_facto') 로 완화
--      - 나머지 로직은 동일 (v1.0 + M12 proxy 확장)
--      - 최종 승인/반려/회수 시 각각 'completed'/'rejected'/'withdrawn'로 전환

-- ─── fn_submit_post_facto ──────────────────────────

CREATE OR REPLACE FUNCTION public.fn_submit_post_facto(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_approval_line jsonb,
  p_reason text,
  p_attachment_ids uuid[] DEFAULT '{}'::uuid[]
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
  v_schema jsonb;
  v_doc_number text;
  v_item jsonb;
  v_index int := 0;
  v_approval_count int := 0;
  v_user_ids uuid[] := '{}';
  v_uid uuid;
  v_amount numeric(14,2) := NULL;
  v_step_type text;
  v_step_status public.step_status;
  v_step_comment text;
  v_delegation_rule record;
  v_first_approval int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- 후결 사유 필수 검증 (초입)
  IF p_reason IS NULL OR char_length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'Post-facto reason required' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  -- 결재선 기본 검증 (fn_submit_draft 동일)
  IF jsonb_typeof(p_approval_line) <> 'array'
     OR jsonb_array_length(p_approval_line) = 0 THEN
    RAISE EXCEPTION 'Approval line must have at least one item' USING ERRCODE = '22023';
  END IF;

  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_uid := (v_item->>'userId')::uuid;
    IF v_uid = ANY(v_user_ids) THEN
      RAISE EXCEPTION 'Duplicate approver in line: %', v_uid USING ERRCODE = '22023';
    END IF;
    v_user_ids := v_user_ids || v_uid;
    IF (v_item->>'stepType') = 'approval' THEN
      v_approval_count := v_approval_count + 1;
    END IF;
  END LOOP;

  IF v_approval_count = 0 THEN
    RAISE EXCEPTION 'At least one approval step required' USING ERRCODE = '22023';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(v_user_ids) AS uid
    WHERE uid NOT IN (
      SELECT user_id FROM public.tenant_members WHERE tenant_id = p_tenant_id
    )
  ) THEN
    RAISE EXCEPTION 'Some approvers are not tenant members' USING ERRCODE = '42501';
  END IF;

  -- 양식 FOR UPDATE (스냅샷 락)
  SELECT schema INTO v_schema
  FROM public.approval_forms
  WHERE id = p_form_id
    AND is_published = true
    AND (tenant_id = p_tenant_id OR tenant_id IS NULL)
  FOR UPDATE;

  IF v_schema IS NULL THEN
    RAISE EXCEPTION 'Form not found or unpublished' USING ERRCODE = '02000';
  END IF;

  v_doc_number := public.fn_next_doc_number(p_tenant_id);

  -- amount 추출 (delegation 매칭용)
  BEGIN
    v_amount := (p_content->>'amount')::numeric;
  EXCEPTION WHEN OTHERS THEN
    v_amount := NULL;
  END;

  -- Document INSERT — status = 'pending_post_facto'
  INSERT INTO public.approval_documents (
    tenant_id, doc_number, form_id, form_schema_snapshot,
    content, drafter_id, status, current_step_index, submitted_at
  )
  VALUES (
    p_tenant_id, v_doc_number, p_form_id, v_schema,
    p_content, v_user_id, 'pending_post_facto', 0, now()
  )
  RETURNING * INTO v_doc;

  -- Steps INSERT + delegation 매칭 (fn_submit_draft v2 로직 재사용)
  v_index := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_step_type := v_item->>'stepType';
    v_uid := (v_item->>'userId')::uuid;
    v_step_status := 'pending';
    v_step_comment := NULL;
    v_delegation_rule := NULL;

    IF v_step_type = 'approval' THEN
      SELECT dr.* INTO v_delegation_rule
        FROM public.delegation_rules dr
       WHERE dr.tenant_id = p_tenant_id
         AND dr.delegator_user_id = v_uid
         AND (dr.form_id = p_form_id OR dr.form_id IS NULL)
         AND (dr.amount_limit IS NULL
              OR (v_amount IS NOT NULL AND v_amount <= dr.amount_limit))
         AND dr.effective_from <= now()
         AND (dr.effective_to IS NULL OR dr.effective_to > now())
       ORDER BY
         (dr.form_id IS NULL) ASC,
         dr.amount_limit ASC NULLS LAST,
         dr.effective_from DESC
       LIMIT 1;

      IF v_delegation_rule.id IS NOT NULL THEN
        v_step_status := 'skipped';
        v_step_comment := format(
          '[전결] delegated to %s (rule %s)',
          v_delegation_rule.delegate_user_id,
          v_delegation_rule.id
        );
      END IF;
    END IF;

    INSERT INTO public.approval_steps (
      tenant_id, document_id, step_index, step_type,
      approver_user_id, status, acted_at, comment
    )
    VALUES (
      p_tenant_id, v_doc.id, v_index,
      v_step_type::public.step_type,
      v_uid,
      v_step_status,
      CASE WHEN v_step_status = 'skipped' THEN now() ELSE NULL END,
      v_step_comment
    );

    IF v_delegation_rule.id IS NOT NULL THEN
      INSERT INTO public.approval_audit_logs (
        tenant_id, document_id, actor_id, action, payload
      ) VALUES (
        p_tenant_id, v_doc.id, v_user_id, 'delegated',
        jsonb_build_object(
          'step_index', v_index,
          'original_approver', v_uid,
          'delegate_to', v_delegation_rule.delegate_user_id,
          'rule_id', v_delegation_rule.id,
          'amount', v_amount
        )
      );
    END IF;

    v_index := v_index + 1;
  END LOOP;

  -- 첫 pending approval step 찾기
  SELECT step_index INTO v_first_approval
  FROM public.approval_steps
  WHERE document_id = v_doc.id
    AND step_type = 'approval'
    AND status = 'pending'
  ORDER BY step_index ASC
  LIMIT 1;

  IF v_first_approval IS NULL THEN
    -- 모든 approval step이 delegation으로 skipped → 자동 완료
    UPDATE public.approval_steps
       SET status = 'skipped'
     WHERE document_id = v_doc.id
       AND status = 'pending';

    UPDATE public.approval_documents
       SET status = 'completed',
           completed_at = now(),
           updated_at = now()
     WHERE id = v_doc.id
    RETURNING * INTO v_doc;

    INSERT INTO public.approval_audit_logs (
      tenant_id, document_id, actor_id, action, payload
    ) VALUES (
      p_tenant_id, v_doc.id, v_user_id, 'delegated',
      jsonb_build_object(
        'auto_completed', true,
        'reason', 'all_approval_steps_delegated',
        'post_facto', true
      )
    );
  ELSIF v_first_approval > 0 THEN
    UPDATE public.approval_documents
    SET current_step_index = v_first_approval
    WHERE id = v_doc.id
    RETURNING * INTO v_doc;
  END IF;

  -- 첨부파일 document_id 확정
  IF array_length(p_attachment_ids, 1) > 0 THEN
    UPDATE public.approval_attachments
    SET document_id = v_doc.id
    WHERE id = ANY(p_attachment_ids)
      AND uploaded_by = v_user_id
      AND document_id IS NULL
      AND tenant_id = p_tenant_id;
  END IF;

  -- 후결 상신 감사 로그 (사유 포함)
  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    p_tenant_id, v_doc.id, v_user_id, 'submitted_post_facto',
    jsonb_build_object(
      'reason', p_reason,
      'approval_line', p_approval_line,
      'attachments', p_attachment_ids
    )
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_post_facto(uuid, uuid, jsonb, jsonb, text, uuid[])
  TO authenticated;

-- ─── fn_approve_step (재정의, pending_post_facto 수용) ──

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

  SELECT * INTO v_doc
  FROM public.approval_documents
  WHERE id = p_document_id
  FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found' USING ERRCODE = '02000';
  END IF;

  -- v1.1 M13: 후결 문서도 수용
  IF v_doc.status NOT IN ('in_progress', 'pending_post_facto') THEN
    RAISE EXCEPTION 'Document not actionable (status: %)', v_doc.status USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

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

  -- Proxy 경로 (M12)
  IF v_step.approver_user_id = v_user_id THEN
    v_proxy := NULL;
  ELSE
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

  UPDATE public.approval_steps
  SET status = 'approved',
      acted_at = now(),
      comment = p_comment,
      acted_by_proxy_user_id = v_proxy
  WHERE id = v_step.id;

  SELECT * INTO v_next_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND step_index > v_doc.current_step_index
    AND step_type = 'approval'
    AND status = 'pending'
  ORDER BY step_index ASC
  LIMIT 1;

  IF v_next_step.id IS NULL THEN
    -- 최종 승인 — 남은 reference step 일괄 skipped + 문서 completed
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

-- ─── fn_reject_step (pending_post_facto 수용) ─────

CREATE OR REPLACE FUNCTION public.fn_reject_step(
  p_document_id uuid,
  p_comment text
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
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_comment IS NULL OR char_length(trim(p_comment)) = 0 THEN
    RAISE EXCEPTION 'Reject reason required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_doc FROM public.approval_documents
  WHERE id = p_document_id FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found' USING ERRCODE = '02000';
  END IF;

  -- v1.1 M13: 후결 문서도 반려 가능
  IF v_doc.status NOT IN ('in_progress', 'pending_post_facto') THEN
    RAISE EXCEPTION 'Document not actionable (status: %)', v_doc.status USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_step FROM public.approval_steps
  WHERE document_id = p_document_id AND step_index = v_doc.current_step_index
  FOR UPDATE;

  IF v_step.approver_user_id <> v_user_id OR v_step.status <> 'pending' THEN
    RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
  END IF;

  IF v_step.step_type <> 'approval' THEN
    RAISE EXCEPTION 'Cannot reject a reference step' USING ERRCODE = '22023';
  END IF;

  UPDATE public.approval_steps
  SET status = 'rejected', acted_at = now(), comment = p_comment
  WHERE id = v_step.id;

  UPDATE public.approval_steps
  SET status = 'skipped'
  WHERE document_id = p_document_id
    AND status = 'pending';

  UPDATE public.approval_documents
  SET status = 'rejected', updated_at = now()
  WHERE id = p_document_id
  RETURNING * INTO v_doc;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'reject',
    jsonb_build_object('step_index', v_step.step_index, 'comment', p_comment)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_reject_step(uuid, text) TO authenticated;

-- ─── fn_withdraw_document (pending_post_facto 수용) ──

CREATE OR REPLACE FUNCTION public.fn_withdraw_document(
  p_document_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_doc public.approval_documents;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_doc FROM public.approval_documents
  WHERE id = p_document_id FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found' USING ERRCODE = '02000';
  END IF;

  IF v_doc.drafter_id <> v_user_id THEN
    RAISE EXCEPTION 'Only drafter can withdraw' USING ERRCODE = '42501';
  END IF;

  -- v1.1 M13: 후결 문서도 회수 가능
  IF v_doc.status NOT IN ('in_progress', 'pending_post_facto') THEN
    RAISE EXCEPTION 'Cannot withdraw this document' USING ERRCODE = '22023';
  END IF;

  UPDATE public.approval_steps
  SET status = 'skipped'
  WHERE document_id = p_document_id AND status = 'pending';

  UPDATE public.approval_documents
  SET status = 'withdrawn', updated_at = now()
  WHERE id = p_document_id
  RETURNING * INTO v_doc;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'withdraw',
    jsonb_build_object('reason', p_reason)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_withdraw_document(uuid, text) TO authenticated;
