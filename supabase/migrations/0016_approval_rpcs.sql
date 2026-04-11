-- 0016_approval_rpcs.sql
-- M5: 결재 mutation RPC 6종. 모든 결재 관련 INSERT/UPDATE는 반드시 이 RPC들을 경유.
-- 모든 함수 공통:
--   - SECURITY DEFINER + SET search_path = public
--   - auth.uid() null check
--   - is_tenant_member 재확인 (RLS 우회 방어)
--   - approval_audit_logs 자동 기록 (호출자 실수 방지)
--   - Risk #13: 문서 완료/반려/회수 시 남은 pending step 일괄 skipped

-- ─── fn_save_draft ──────────────────────────────────
-- 임시저장. document_id 있으면 UPDATE, 없으면 INSERT.
-- 결재선은 저장하지 않음. form_schema_snapshot은 현재 form.schema 복사.

CREATE OR REPLACE FUNCTION public.fn_save_draft(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
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
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  -- 양식 존재·발행 확인 (시스템 양식은 tenant_id IS NULL, 테넌트 양식은 매칭)
  SELECT schema INTO v_schema
  FROM public.approval_forms
  WHERE id = p_form_id
    AND is_published = true
    AND (tenant_id = p_tenant_id OR tenant_id IS NULL);

  IF v_schema IS NULL THEN
    RAISE EXCEPTION 'Form not found or unpublished' USING ERRCODE = '02000';
  END IF;

  IF p_document_id IS NULL THEN
    -- 신규 draft 생성 (doc_number는 임시, 상신 시 정식 번호로 교체)
    INSERT INTO public.approval_documents (
      tenant_id, doc_number, form_id, form_schema_snapshot,
      content, drafter_id, status
    )
    VALUES (
      p_tenant_id,
      'DRAFT-' || gen_random_uuid()::text,
      p_form_id,
      v_schema,
      p_content,
      v_user_id,
      'draft'
    )
    RETURNING * INTO v_doc;
  ELSE
    -- 기존 draft 업데이트
    UPDATE public.approval_documents
    SET content = p_content,
        form_schema_snapshot = v_schema,  -- 최신 schema로 교체 (draft는 유연)
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

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    p_tenant_id, v_doc.id, v_user_id, 'draft_saved', '{}'::jsonb
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_save_draft(uuid, uuid, jsonb, uuid) TO authenticated;

-- ─── fn_submit_draft ────────────────────────────────
-- 상신. draft → in_progress. 결재선 스냅샷 + 첨부 확정.

CREATE OR REPLACE FUNCTION public.fn_submit_draft(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_approval_line jsonb,          -- ApprovalLineItem[]
  p_attachment_ids uuid[] DEFAULT '{}'::uuid[],
  p_document_id uuid DEFAULT NULL -- 기존 draft를 상신 시 전달
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
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  -- 결재선 기본 검증
  IF jsonb_typeof(p_approval_line) <> 'array'
     OR jsonb_array_length(p_approval_line) = 0 THEN
    RAISE EXCEPTION 'Approval line must have at least one item' USING ERRCODE = '22023';
  END IF;

  -- 결재선 중복 방지 + approval step 최소 1개 검증
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

  -- 결재선 구성원이 모두 테넌트 멤버인지 확인
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

  -- 결재선 스냅샷 INSERT
  v_index := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    INSERT INTO public.approval_steps (
      tenant_id, document_id, step_index, step_type,
      approver_user_id, status
    )
    VALUES (
      p_tenant_id, v_doc.id, v_index,
      (v_item->>'stepType')::public.step_type,
      (v_item->>'userId')::uuid,
      'pending'
    );
    v_index := v_index + 1;
  END LOOP;

  -- 첫 단계가 reference면 approval 단계를 찾아 current_step_index 조정
  DECLARE
    v_first_approval int;
  BEGIN
    SELECT step_index INTO v_first_approval
    FROM public.approval_steps
    WHERE document_id = v_doc.id AND step_type = 'approval'
    ORDER BY step_index ASC
    LIMIT 1;
    IF v_first_approval IS NOT NULL AND v_first_approval > 0 THEN
      UPDATE public.approval_documents
      SET current_step_index = v_first_approval
      WHERE id = v_doc.id
      RETURNING * INTO v_doc;
    END IF;
  END;

  -- 첨부파일 document_id 확정
  IF array_length(p_attachment_ids, 1) > 0 THEN
    UPDATE public.approval_attachments
    SET document_id = v_doc.id
    WHERE id = ANY(p_attachment_ids)
      AND uploaded_by = v_user_id
      AND document_id IS NULL
      AND tenant_id = p_tenant_id;
  END IF;

  -- 감사 로그
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

-- ─── fn_approve_step ────────────────────────────────
-- 현재 단계 승인 + 다음 approval step 이동 + 마지막이면 completed.
-- Risk #13: 완료 시 남은 pending reference step을 skipped로 일괄 처리.

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

  -- 현재 step 잠금 + 검증
  SELECT * INTO v_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND step_index = v_doc.current_step_index
  FOR UPDATE;

  IF v_step.id IS NULL THEN
    RAISE EXCEPTION 'Current step not found' USING ERRCODE = '02000';
  END IF;

  IF v_step.approver_user_id <> v_user_id THEN
    RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
  END IF;

  IF v_step.status <> 'pending' THEN
    RAISE EXCEPTION 'Step not pending' USING ERRCODE = '22023';
  END IF;

  IF v_step.step_type <> 'approval' THEN
    RAISE EXCEPTION 'Cannot approve a reference step' USING ERRCODE = '22023';
  END IF;

  UPDATE public.approval_steps
  SET status = 'approved', acted_at = now(), comment = p_comment
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

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'approve',
    jsonb_build_object('step_index', v_step.step_index, 'comment', p_comment)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_approve_step(uuid, text) TO authenticated;

-- ─── fn_reject_step ─────────────────────────────────
-- 반려. 사유 필수. 이후 단계 모두 skipped + document rejected.

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

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Document not in progress' USING ERRCODE = '22023';
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

  -- 이후 모든 pending step(approval + reference)을 skipped
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

-- ─── fn_withdraw_document ───────────────────────────
-- 회수. 기안자만 가능. in_progress 상태에서만.

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

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'Cannot withdraw this document' USING ERRCODE = '22023';
  END IF;

  -- pending 단계 모두 skipped
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

-- ─── fn_add_comment ─────────────────────────────────
-- 코멘트 추가. drafter/admin/approver만 가능.
-- 별도 테이블 없이 audit_logs에 기록.

CREATE OR REPLACE FUNCTION public.fn_add_comment(
  p_document_id uuid,
  p_comment text
)
RETURNS void
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

  IF p_comment IS NULL OR char_length(trim(p_comment)) = 0 THEN
    RAISE EXCEPTION 'Comment required' USING ERRCODE = '22023';
  END IF;

  SELECT * INTO v_doc FROM public.approval_documents WHERE id = p_document_id;

  IF v_doc.id IS NULL OR NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Document not accessible' USING ERRCODE = '42501';
  END IF;

  -- 접근권: drafter OR admin OR approver
  IF NOT (
    v_doc.drafter_id = v_user_id
    OR public.is_tenant_admin(v_doc.tenant_id)
    OR EXISTS (
      SELECT 1 FROM public.approval_steps s
      WHERE s.document_id = v_doc.id AND s.approver_user_id = v_user_id
    )
  ) THEN
    RAISE EXCEPTION 'No access to this document' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id, 'comment',
    jsonb_build_object('comment', p_comment)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_add_comment(uuid, text) TO authenticated;
