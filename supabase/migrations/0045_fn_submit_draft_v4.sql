-- 0045_fn_submit_draft_v4.sql
-- v2.0 M29: fn_submit_draft에 자동 결재선 분기 추가.
-- p_approval_line이 빈 배열('[]')이면 fn_resolve_approval_line으로 자동 구성.
-- 기존 v3 시그니처 그대로 유지 (하위 호환).
-- Design: §8

BEGIN;

-- fn_submit_draft 재생성 (v4: auto approval line 분기만 추가)
-- 기존 v3 본문을 복사하되 p_approval_line '[]' 체크 추가
CREATE OR REPLACE FUNCTION public.fn_submit_draft(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_approval_line jsonb,
  p_content_hash text,
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
  v_form record;
  v_doc public.approval_documents;
  v_doc_number text;
  v_item jsonb;
  v_index int := 0;
  v_group_order int;
  v_step_user uuid;
  v_step_type text;
  v_deleg record;
  v_first_approval int := NULL;
  v_att_id uuid;
  v_prev_groups int[];
  v_auto_line jsonb;
BEGIN
  -- 0. membership 확인
  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  -- 1. content_hash 검증
  IF p_content_hash IS NULL OR char_length(p_content_hash) <> 64
     OR p_content_hash !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'Invalid content_hash: must be 64 hex chars' USING ERRCODE = '22023';
  END IF;

  -- 2. form 조회
  SELECT * INTO v_form
  FROM public.approval_forms
  WHERE id = p_form_id AND tenant_id = p_tenant_id AND is_published = true;
  IF v_form.id IS NULL THEN
    RAISE EXCEPTION 'Form not found or not published' USING ERRCODE = '02000';
  END IF;

  -- ── v2.0: 빈 결재선 → 자동 구성 ───────────────────────────
  IF p_approval_line IS NULL OR jsonb_array_length(p_approval_line) = 0 THEN
    v_auto_line := public.fn_resolve_approval_line(p_tenant_id, p_form_id, p_content);
    IF jsonb_array_length(v_auto_line) = 0 THEN
      RAISE EXCEPTION 'No approval rules matched. Please provide an approval line manually.' USING ERRCODE = '22023';
    END IF;
    p_approval_line := v_auto_line;
  END IF;

  -- 3. approval_line 검증
  IF jsonb_array_length(p_approval_line) = 0 THEN
    RAISE EXCEPTION 'Approval line must have at least one step' USING ERRCODE = '22023';
  END IF;

  -- groupOrder 연속성 검증
  v_prev_groups := ARRAY[]::int[];
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_group_order := COALESCE((v_item->>'groupOrder')::int, v_index);
    IF NOT (v_group_order = ANY(v_prev_groups)) THEN
      v_prev_groups := v_prev_groups || v_group_order;
    END IF;
    v_index := v_index + 1;
  END LOOP;

  -- gap 검증: 정렬 후 0,1,2,... 연속인지
  SELECT array_agg(x ORDER BY x) INTO v_prev_groups FROM unnest(v_prev_groups) AS x;
  FOR v_index IN 0 .. array_length(v_prev_groups, 1) - 1 LOOP
    IF v_prev_groups[v_index + 1] <> v_index THEN
      RAISE EXCEPTION 'groupOrder must be contiguous from 0 (no gaps)' USING ERRCODE = '22023';
    END IF;
  END LOOP;

  -- 각 그룹에 최소 1개 approval step 검증
  FOR v_index IN 0 .. v_prev_groups[array_length(v_prev_groups, 1)] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(p_approval_line) AS el
      WHERE COALESCE((el->>'groupOrder')::int, 0) = v_index
        AND COALESCE(el->>'stepType', 'approval') = 'approval'
    ) THEN
      RAISE EXCEPTION 'Group % has no approval step', v_index USING ERRCODE = '22023';
    END IF;
  END LOOP;

  -- 4. attachment sha256 검증
  IF array_length(p_attachment_ids, 1) > 0 THEN
    IF EXISTS (
      SELECT 1 FROM public.approval_attachments
      WHERE id = ANY(p_attachment_ids)
        AND sha256 IS NULL
    ) THEN
      RAISE EXCEPTION 'Some attachments are missing sha256' USING ERRCODE = '22023';
    END IF;
  END IF;

  -- 5. document number 생성
  v_doc_number := public.fn_next_doc_number(p_tenant_id);

  -- 6. 기존 draft 또는 신규
  IF p_document_id IS NOT NULL THEN
    UPDATE public.approval_documents SET
      form_id = p_form_id,
      form_schema_snapshot = v_form.schema,
      content = p_content,
      content_hash = p_content_hash,
      doc_number = v_doc_number,
      status = 'in_progress',
      submitted_at = now(),
      updated_at = now()
    WHERE id = p_document_id AND drafter_id = v_user_id AND tenant_id = p_tenant_id AND status = 'draft'
    RETURNING * INTO v_doc;
    IF v_doc.id IS NULL THEN
      RAISE EXCEPTION 'Draft not found or not owned' USING ERRCODE = '02000';
    END IF;
    -- 기존 steps 삭제
    DELETE FROM public.approval_steps WHERE document_id = v_doc.id;
  ELSE
    INSERT INTO public.approval_documents
      (tenant_id, form_id, form_schema_snapshot, content, content_hash, drafter_id, doc_number, status, submitted_at)
    VALUES
      (p_tenant_id, p_form_id, v_form.schema, p_content, p_content_hash, v_user_id, v_doc_number, 'in_progress', now())
    RETURNING * INTO v_doc;
  END IF;

  -- 7. steps 생성 + delegation 매칭
  v_index := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_step_user := (v_item->>'userId')::uuid;
    v_step_type := COALESCE(v_item->>'stepType', 'approval');
    v_group_order := COALESCE((v_item->>'groupOrder')::int, v_index);

    -- delegation 매칭
    SELECT * INTO v_deleg
    FROM public.delegation_rules
    WHERE tenant_id = p_tenant_id
      AND delegator_id = v_step_user
      AND is_active = true
      AND effective_from <= now()
      AND (effective_until IS NULL OR effective_until >= now())
      AND (form_id IS NULL OR form_id = p_form_id)
    ORDER BY (form_id IS NULL) ASC, amount_limit ASC NULLS LAST, effective_from DESC
    LIMIT 1;

    IF v_deleg.id IS NOT NULL AND v_step_type = 'approval' THEN
      -- delegation skip
      INSERT INTO public.approval_steps
        (document_id, step_index, group_order, step_type, approver_user_id, status, comment)
      VALUES
        (v_doc.id, v_index, v_group_order, v_step_type, v_step_user, 'skipped', '[전결] ' || COALESCE(v_deleg.delegate_id::text, ''));

      INSERT INTO public.approval_audit_logs
        (tenant_id, document_id, actor_id, action, payload)
      VALUES
        (p_tenant_id, v_doc.id, v_step_user, 'delegated'::public.audit_action,
         jsonb_build_object('step_index', v_index, 'delegate_id', v_deleg.delegate_id, 'rule_id', v_deleg.id));
    ELSE
      INSERT INTO public.approval_steps
        (document_id, step_index, group_order, step_type, approver_user_id, status)
      VALUES
        (v_doc.id, v_index, v_group_order, v_step_type, v_step_user, 'pending');

      IF v_first_approval IS NULL AND v_step_type = 'approval' THEN
        v_first_approval := v_group_order;
      END IF;
    END IF;

    v_index := v_index + 1;
  END LOOP;

  -- 8. attachment 연결
  IF array_length(p_attachment_ids, 1) > 0 THEN
    UPDATE public.approval_attachments
    SET document_id = v_doc.id
    WHERE id = ANY(p_attachment_ids);
  END IF;

  -- 9. advance document (첫 활성 그룹 탐색)
  PERFORM public.fn_advance_document(v_doc.id);

  -- 10. 모든 step이 delegated → auto complete
  IF NOT EXISTS (
    SELECT 1 FROM public.approval_steps
    WHERE document_id = v_doc.id AND step_type = 'approval' AND status = 'pending'
  ) THEN
    UPDATE public.approval_documents SET
      status = 'completed', completed_at = now(), updated_at = now()
    WHERE id = v_doc.id
    RETURNING * INTO v_doc;

    INSERT INTO public.approval_audit_logs
      (tenant_id, document_id, actor_id, action, payload)
    VALUES
      (p_tenant_id, v_doc.id, v_user_id, 'approve'::public.audit_action,
       jsonb_build_object('auto_completed', true, 'reason', 'All approval steps delegated'));
  END IF;

  -- 11. audit log
  INSERT INTO public.approval_audit_logs
    (tenant_id, document_id, actor_id, action, payload)
  VALUES
    (p_tenant_id, v_doc.id, v_user_id, 'submit'::public.audit_action,
     jsonb_build_object('content_hash', p_content_hash, 'attachments', p_attachment_ids));

  SELECT * INTO v_doc FROM public.approval_documents WHERE id = v_doc.id;
  RETURN v_doc;
END;
$$;

COMMIT;
