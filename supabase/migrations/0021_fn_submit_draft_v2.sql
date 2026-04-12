-- 0021_fn_submit_draft_v2.sql
-- v1.1 M11: fn_submit_draft 교체 — 전결 매칭 로직 추가.
--
-- v1.0 대비 변경점:
--   1. content->>'amount'에서 금액 추출 시도 (실패 시 NULL)
--   2. approval step 삽입 시 delegation_rules 매칭
--      - 매칭 시 status='skipped' + audit 'delegated' 기록
--   3. current_step_index 조정 시 status='pending'인 첫 approval step 선택
--      (delegation으로 skipped된 step 건너뛰기)
--   4. 모든 approval step이 delegation으로 skipped → 자동 completed 처리
--      (한국 전결 의미상 "정책 기반 완전 승인"에 해당)
--
-- 시그니처는 v1.0과 동일 (호출부 호환):
--   fn_submit_draft(tenant_id, form_id, content, approval_line, attachment_ids, document_id)

CREATE OR REPLACE FUNCTION public.fn_submit_draft(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_approval_line jsonb,
  p_attachment_ids uuid[] DEFAULT '{}'::uuid[],
  p_document_id uuid DEFAULT NULL
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

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  -- 결재선 기본 검증 (v1.0 동일)
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

  -- 양식 확인
  SELECT schema INTO v_schema
  FROM public.approval_forms
  WHERE id = p_form_id
    AND is_published = true
    AND (tenant_id = p_tenant_id OR tenant_id IS NULL);

  IF v_schema IS NULL THEN
    RAISE EXCEPTION 'Form not found or unpublished' USING ERRCODE = '02000';
  END IF;

  v_doc_number := public.fn_next_doc_number(p_tenant_id);

  -- v1.1: amount 추출 시도 (content.amount → numeric, 실패 시 NULL)
  BEGIN
    v_amount := (p_content->>'amount')::numeric;
  EXCEPTION WHEN OTHERS THEN
    v_amount := NULL;
  END;

  -- document INSERT / UPDATE (v1.0 동일)
  IF p_document_id IS NULL THEN
    INSERT INTO public.approval_documents (
      tenant_id, doc_number, form_id, form_schema_snapshot,
      content, drafter_id, status, current_step_index, submitted_at
    )
    VALUES (
      p_tenant_id, v_doc_number, p_form_id, v_schema,
      p_content, v_user_id, 'in_progress', 0, now()
    )
    RETURNING * INTO v_doc;
  ELSE
    UPDATE public.approval_documents
    SET doc_number = v_doc_number,
        form_schema_snapshot = v_schema,
        content = p_content,
        status = 'in_progress',
        current_step_index = 0,
        submitted_at = now(),
        updated_at = now()
    WHERE id = p_document_id
      AND drafter_id = v_user_id
      AND status = 'draft'
      AND tenant_id = p_tenant_id
    RETURNING * INTO v_doc;

    IF v_doc.id IS NULL THEN
      RAISE EXCEPTION 'Draft not found or not owned' USING ERRCODE = '42501';
    END IF;
  END IF;

  -- 결재선 스냅샷 INSERT + v1.1 delegation 매칭
  v_index := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_step_type := v_item->>'stepType';
    v_uid := (v_item->>'userId')::uuid;
    v_step_status := 'pending';
    v_step_comment := NULL;
    v_delegation_rule := NULL;

    -- delegation 매칭은 approval step만
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

    -- 감사 로그: delegation으로 skip된 경우
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

  -- 첫 approval step(pending) 찾기 → current_step_index 조정
  -- (delegation으로 skipped된 step은 건너뜀)
  SELECT step_index INTO v_first_approval
  FROM public.approval_steps
  WHERE document_id = v_doc.id
    AND step_type = 'approval'
    AND status = 'pending'
  ORDER BY step_index ASC
  LIMIT 1;

  IF v_first_approval IS NULL THEN
    -- 모든 approval step이 delegation으로 skipped → 한국 전결 의미상 자동 완료
    -- Risk #13과 동일한 처리: 남은 pending reference step들도 일괄 skipped
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
        'reason', 'all_approval_steps_delegated'
      )
    );
  ELSIF v_first_approval > 0 THEN
    UPDATE public.approval_documents
    SET current_step_index = v_first_approval
    WHERE id = v_doc.id
    RETURNING * INTO v_doc;
  END IF;

  -- 첨부파일 document_id 확정 (v1.0 동일)
  IF array_length(p_attachment_ids, 1) > 0 THEN
    UPDATE public.approval_attachments
    SET document_id = v_doc.id
    WHERE id = ANY(p_attachment_ids)
      AND uploaded_by = v_user_id
      AND document_id IS NULL
      AND tenant_id = p_tenant_id;
  END IF;

  -- 감사 로그 (v1.0 동일)
  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    p_tenant_id, v_doc.id, v_user_id, 'submit',
    jsonb_build_object('approval_line', p_approval_line, 'attachments', p_attachment_ids)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_draft(uuid, uuid, jsonb, jsonb, uuid[], uuid)
  TO authenticated;
