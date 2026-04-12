-- 0031_fn_advance_document.sql
-- v1.2 M15: fn_advance_document helper 추출 (v1.1 잔여 G4 이월) + group_order 컬럼 도입
--           + v1.1 fn_submit_draft / fn_submit_post_facto 에 transitional group_order 패치.
--
-- 원자화 이유:
--   group_order 컬럼 NOT NULL + helper + 기존 RPC 패치 를 같은 파일에서 생성해야
--   중간 상태 (컬럼 있음, RPC 미갱신 → INSERT 실패) 를 피할 수 있음.
--
-- 변경 요약:
--   1. approval_steps.group_order int NOT NULL 컬럼 추가 (backfill = step_index)
--   2. CHECK (group_order >= 0) + 인덱스 (document_id, group_order, status)
--   3. fn_advance_document(p_document_id) 함수 생성
--   4. v1.1 fn_submit_draft (0021) / fn_submit_post_facto (0026) 을 minimal 패치:
--      INSERT INTO approval_steps 에 group_order = v_index 추가 (순차 시맨틱 유지).
--      0035 에서 v3 로 완전 교체 예정 (groupOrder 파라미터 + content_hash).
--
-- 의미 재정의:
--   approval_documents.current_step_index 가 v1.1 까지 "step_index pointer" 였으나,
--   v1.2 이후 "group_order pointer" 로 의미 재정의.
--   기존 v1.0/v1.1 문서는 group_order = step_index 로 backfill 되므로 값 동일.
--
-- 회귀 안전성:
--   - v1.1 smoke (tests/smoke/v1.1-korean-exceptions.sql) 4/4 PASS 여야 함
--   - backfill 검증: SELECT count(*) FILTER (WHERE group_order <> step_index) = 0

BEGIN;

-- ─── Step 1: approval_steps.group_order 컬럼 추가 ─────────────

ALTER TABLE public.approval_steps
  ADD COLUMN IF NOT EXISTS group_order int NOT NULL DEFAULT 0;

-- backfill: 기존 행은 step_index 를 group_order 로 (순차 시맨틱)
UPDATE public.approval_steps
   SET group_order = step_index
 WHERE group_order = 0 AND step_index > 0;

-- DEFAULT 제거 (신규 insert 에서 명시 강제)
ALTER TABLE public.approval_steps
  ALTER COLUMN group_order DROP DEFAULT;

ALTER TABLE public.approval_steps
  DROP CONSTRAINT IF EXISTS as_group_order_nonneg;
ALTER TABLE public.approval_steps
  ADD CONSTRAINT as_group_order_nonneg CHECK (group_order >= 0);

CREATE INDEX IF NOT EXISTS as_document_group_idx
  ON public.approval_steps (document_id, group_order, status);

COMMENT ON COLUMN public.approval_steps.group_order IS
  'v1.2 M15 — parallel group pointer. Same value = parallel approvers, increasing = sequential. Backfilled from step_index for pre-v1.2 rows.';

COMMENT ON COLUMN public.approval_documents.current_step_index IS
  'v1.0/v1.1: step_index pointer. v1.2 이후: group_order pointer (의미 재정의). 기존 문서는 group_order = step_index 이므로 값 동일.';

-- ─── Step 2: fn_advance_document helper (병렬·순차 공용) ─────

CREATE OR REPLACE FUNCTION public.fn_advance_document(p_document_id uuid)
RETURNS public.approval_documents
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc public.approval_documents;
  v_current_group int;
  v_has_pending boolean;
  v_next_group int;
BEGIN
  SELECT * INTO v_doc
    FROM public.approval_documents
   WHERE id = p_document_id
   FOR UPDATE;

  IF v_doc.id IS NULL THEN
    RAISE EXCEPTION 'Document not found: %', p_document_id USING ERRCODE = '02000';
  END IF;

  -- 종결 상태면 변경 없이 반환 (멱등)
  IF v_doc.status NOT IN ('in_progress', 'pending_post_facto') THEN
    RETURN v_doc;
  END IF;

  v_current_group := v_doc.current_step_index;

  -- 현재 group 내 pending approval step 있는지
  SELECT EXISTS (
    SELECT 1
      FROM public.approval_steps
     WHERE document_id = p_document_id
       AND group_order = v_current_group
       AND step_type = 'approval'
       AND status = 'pending'
  ) INTO v_has_pending;

  IF v_has_pending THEN
    RETURN v_doc;  -- 그룹 미완
  END IF;

  -- 다음 pending approval group 탐색
  SELECT MIN(group_order) INTO v_next_group
    FROM public.approval_steps
   WHERE document_id = p_document_id
     AND group_order > v_current_group
     AND step_type = 'approval'
     AND status = 'pending';

  IF v_next_group IS NULL THEN
    -- 모든 approval 완료 → document completed
    -- v1.0 Risk #13 재현: 남은 pending reference step 일괄 skipped
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
       SET current_step_index = v_next_group,
           updated_at = now()
     WHERE id = p_document_id
    RETURNING * INTO v_doc;
  END IF;

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_advance_document(uuid) TO authenticated;

COMMENT ON FUNCTION public.fn_advance_document(uuid) IS
  'v1.2 M15 — group-based document advancement helper. Called from fn_submit_draft/post_facto and fn_approve_step. Handles parallel (same group_order) and sequential (increasing group_order) in a single logic path.';

-- ─── Step 3: v1.1 RPCs transitional patch (group_order = v_index) ──
-- 0035 에서 v3 로 완전 교체될 예정. 중간 상태에서도 INSERT 가 실패하지 않도록
-- step_index 와 동일한 값을 group_order 에 넣어 순차 시맨틱을 유지.

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

  SELECT schema INTO v_schema
  FROM public.approval_forms
  WHERE id = p_form_id
    AND is_published = true
    AND (tenant_id = p_tenant_id OR tenant_id IS NULL);

  IF v_schema IS NULL THEN
    RAISE EXCEPTION 'Form not found or unpublished' USING ERRCODE = '02000';
  END IF;

  v_doc_number := public.fn_next_doc_number(p_tenant_id);

  BEGIN
    v_amount := (p_content->>'amount')::numeric;
  EXCEPTION WHEN OTHERS THEN
    v_amount := NULL;
  END;

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

    -- v1.2 M15 patch: group_order = v_index (순차, 0035 에서 완전 교체)
    INSERT INTO public.approval_steps (
      tenant_id, document_id, step_index, group_order, step_type,
      approver_user_id, status, acted_at, comment
    )
    VALUES (
      p_tenant_id, v_doc.id, v_index, v_index,
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

  SELECT step_index INTO v_first_approval
  FROM public.approval_steps
  WHERE document_id = v_doc.id
    AND step_type = 'approval'
    AND status = 'pending'
  ORDER BY step_index ASC
  LIMIT 1;

  IF v_first_approval IS NULL THEN
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

  IF array_length(p_attachment_ids, 1) > 0 THEN
    UPDATE public.approval_attachments
    SET document_id = v_doc.id
    WHERE id = ANY(p_attachment_ids)
      AND uploaded_by = v_user_id
      AND document_id IS NULL
      AND tenant_id = p_tenant_id;
  END IF;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    p_tenant_id, v_doc.id, v_user_id, 'submit',
    jsonb_build_object('approval_line', p_approval_line, 'attachments', p_attachment_ids)
  );

  RETURN v_doc;
END;
$$;

-- fn_submit_post_facto 도 동일 패치 (minimal group_order = v_index 추가)

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

  IF p_reason IS NULL OR char_length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'Post-facto reason required' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

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

  BEGIN
    v_amount := (p_content->>'amount')::numeric;
  EXCEPTION WHEN OTHERS THEN
    v_amount := NULL;
  END;

  INSERT INTO public.approval_documents (
    tenant_id, doc_number, form_id, form_schema_snapshot,
    content, drafter_id, status, current_step_index, submitted_at
  )
  VALUES (
    p_tenant_id, v_doc_number, p_form_id, v_schema,
    p_content, v_user_id, 'pending_post_facto', 0, now()
  )
  RETURNING * INTO v_doc;

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

    -- v1.2 M15 patch: group_order = v_index
    INSERT INTO public.approval_steps (
      tenant_id, document_id, step_index, group_order, step_type,
      approver_user_id, status, acted_at, comment
    )
    VALUES (
      p_tenant_id, v_doc.id, v_index, v_index,
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

  SELECT step_index INTO v_first_approval
  FROM public.approval_steps
  WHERE document_id = v_doc.id
    AND step_type = 'approval'
    AND status = 'pending'
  ORDER BY step_index ASC
  LIMIT 1;

  IF v_first_approval IS NULL THEN
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

  IF array_length(p_attachment_ids, 1) > 0 THEN
    UPDATE public.approval_attachments
    SET document_id = v_doc.id
    WHERE id = ANY(p_attachment_ids)
      AND uploaded_by = v_user_id
      AND document_id IS NULL
      AND tenant_id = p_tenant_id;
  END IF;

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

COMMIT;
