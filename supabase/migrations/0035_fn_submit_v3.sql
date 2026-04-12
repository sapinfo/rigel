-- 0035_fn_submit_v3.sql
-- v1.2 M16b: fn_submit_draft / fn_submit_post_facto 완전 교체 (v3 / v2).
--
-- 주요 변경:
--   1. p_content_hash text 파라미터 신규 (NOT NULL, 64-char lowercase hex 강제)
--   2. p_approval_line item 에 groupOrder(int, optional) 추가
--      - 미지정 시 순차 (v_index fallback)
--      - 지정 시: set == {0, 1, ..., K-1} 연속성 (gap 금지)
--      - 각 group 에 최소 1개 approval step
--   3. attachments sha256 NULL 체크 (submit 시 전부 채워져 있어야 함)
--   4. 마지막에 fn_advance_document(v_doc.id) 호출로 첫 활성 group 탐색
--   5. audit 'submit'/'submitted_post_facto' payload 에 content_hash mirror
--
-- DROP FUNCTION: v1.1 legacy signatures (6-param) 을 제거 —
--   overload 허용 시 old 버전이 여전히 호출 가능하므로 v1.2 guarantee 를 우회할 수 있음.
--
-- 회귀 안전성:
--   - v1.1 smoke (tests/smoke/v1.1-korean-exceptions.sql) 은 M16b 에서 v3 signature 로 호출
--     되도록 업데이트됨 (placeholder content_hash 'a' * 64 사용). 여전히 4/4 PASS.

BEGIN;

-- ─── Legacy (v1.1) 6-param DROP ─────────────────────────────

DROP FUNCTION IF EXISTS public.fn_submit_draft(uuid, uuid, jsonb, jsonb, uuid[], uuid);
DROP FUNCTION IF EXISTS public.fn_submit_post_facto(uuid, uuid, jsonb, jsonb, text, uuid[]);

-- ─── fn_submit_draft v3 ─────────────────────────────────────

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
  v_doc public.approval_documents;
  v_schema jsonb;
  v_doc_number text;
  v_item jsonb;
  v_index int := 0;
  v_group_order int;
  v_approval_count int := 0;
  v_user_ids uuid[] := '{}';
  v_uid uuid;
  v_amount numeric(14,2) := NULL;
  v_step_type text;
  v_step_status public.step_status;
  v_step_comment text;
  v_delegation_rule record;
  v_group_orders int[] := '{}';
  v_max_group int := -1;
  v_group_approval_counts int[];
  v_i int;
  v_missing_attachments int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_content_hash IS NULL OR char_length(p_content_hash) <> 64 THEN
    RAISE EXCEPTION 'Invalid content_hash (must be 64 hex chars)' USING ERRCODE = '22023';
  END IF;
  IF p_content_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Invalid content_hash format' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  IF jsonb_typeof(p_approval_line) <> 'array'
     OR jsonb_array_length(p_approval_line) = 0 THEN
    RAISE EXCEPTION 'Approval line must have at least one item' USING ERRCODE = '22023';
  END IF;

  v_index := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_uid := (v_item->>'userId')::uuid;
    IF v_uid = ANY(v_user_ids) THEN
      RAISE EXCEPTION 'Duplicate approver in line: %', v_uid USING ERRCODE = '22023';
    END IF;
    v_user_ids := v_user_ids || v_uid;

    IF (v_item->>'stepType') = 'approval' THEN
      v_approval_count := v_approval_count + 1;
    END IF;

    v_group_order := COALESCE((v_item->>'groupOrder')::int, v_index);
    IF v_group_order < 0 THEN
      RAISE EXCEPTION 'groupOrder must be >= 0' USING ERRCODE = '22023';
    END IF;
    v_group_orders := v_group_orders || v_group_order;
    IF v_group_order > v_max_group THEN
      v_max_group := v_group_order;
    END IF;

    v_index := v_index + 1;
  END LOOP;

  IF v_approval_count = 0 THEN
    RAISE EXCEPTION 'At least one approval step required' USING ERRCODE = '22023';
  END IF;

  -- group_order 연속성 검증
  IF (SELECT count(DISTINCT g) FROM unnest(v_group_orders) AS g) <> v_max_group + 1 THEN
    RAISE EXCEPTION 'groupOrder must be contiguous from 0 (no gaps)' USING ERRCODE = '22023';
  END IF;

  -- 각 그룹에 최소 1 approval
  v_group_approval_counts := array_fill(0, ARRAY[v_max_group + 1]);
  v_i := 1;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_group_order := v_group_orders[v_i];
    IF (v_item->>'stepType') = 'approval' THEN
      v_group_approval_counts[v_group_order + 1] :=
        v_group_approval_counts[v_group_order + 1] + 1;
    END IF;
    v_i := v_i + 1;
  END LOOP;
  FOR v_i IN 1..(v_max_group + 1) LOOP
    IF v_group_approval_counts[v_i] = 0 THEN
      RAISE EXCEPTION 'Group % has no approval step', v_i - 1 USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM unnest(v_user_ids) AS uid
    WHERE uid NOT IN (
      SELECT user_id FROM public.tenant_members WHERE tenant_id = p_tenant_id
    )
  ) THEN
    RAISE EXCEPTION 'Some approvers are not tenant members' USING ERRCODE = '42501';
  END IF;

  IF array_length(p_attachment_ids, 1) > 0 THEN
    SELECT count(*) INTO v_missing_attachments
    FROM public.approval_attachments
    WHERE id = ANY(p_attachment_ids)
      AND sha256 IS NULL;
    IF v_missing_attachments > 0 THEN
      RAISE EXCEPTION 'Some attachments are missing sha256' USING ERRCODE = '22023';
    END IF;
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
      content, content_hash, drafter_id, status, current_step_index, submitted_at
    )
    VALUES (
      p_tenant_id, v_doc_number, p_form_id, v_schema,
      p_content, p_content_hash, v_user_id, 'in_progress', 0, now()
    )
    RETURNING * INTO v_doc;
  ELSE
    UPDATE public.approval_documents
    SET doc_number = v_doc_number,
        form_schema_snapshot = v_schema,
        content = p_content,
        content_hash = p_content_hash,
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
    v_group_order := COALESCE((v_item->>'groupOrder')::int, v_index);
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
      tenant_id, document_id, step_index, group_order, step_type,
      approver_user_id, status, acted_at, comment
    )
    VALUES (
      p_tenant_id, v_doc.id, v_index, v_group_order,
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
          'group_order', v_group_order,
          'original_approver', v_uid,
          'delegate_to', v_delegation_rule.delegate_user_id,
          'rule_id', v_delegation_rule.id,
          'amount', v_amount
        )
      );
    END IF;

    v_index := v_index + 1;
  END LOOP;

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
    jsonb_build_object(
      'content_hash', p_content_hash,
      'approval_line', p_approval_line,
      'attachments', p_attachment_ids
    )
  );

  v_doc := public.fn_advance_document(v_doc.id);

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_draft(uuid, uuid, jsonb, jsonb, text, uuid[], uuid)
  TO authenticated;

-- ─── fn_submit_post_facto v2 ────────────────────────────────

CREATE OR REPLACE FUNCTION public.fn_submit_post_facto(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb,
  p_approval_line jsonb,
  p_content_hash text,
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
  v_group_order int;
  v_approval_count int := 0;
  v_user_ids uuid[] := '{}';
  v_uid uuid;
  v_amount numeric(14,2) := NULL;
  v_step_type text;
  v_step_status public.step_status;
  v_step_comment text;
  v_delegation_rule record;
  v_group_orders int[] := '{}';
  v_max_group int := -1;
  v_group_approval_counts int[];
  v_i int;
  v_missing_attachments int;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  -- 후결 사유 먼저 (v1.1 M13 유지)
  IF p_reason IS NULL OR char_length(trim(p_reason)) = 0 THEN
    RAISE EXCEPTION 'Post-facto reason required' USING ERRCODE = '22023';
  END IF;

  IF p_content_hash IS NULL OR char_length(p_content_hash) <> 64 THEN
    RAISE EXCEPTION 'Invalid content_hash (must be 64 hex chars)' USING ERRCODE = '22023';
  END IF;
  IF p_content_hash !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'Invalid content_hash format' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(p_tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  IF jsonb_typeof(p_approval_line) <> 'array'
     OR jsonb_array_length(p_approval_line) = 0 THEN
    RAISE EXCEPTION 'Approval line must have at least one item' USING ERRCODE = '22023';
  END IF;

  v_index := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_uid := (v_item->>'userId')::uuid;
    IF v_uid = ANY(v_user_ids) THEN
      RAISE EXCEPTION 'Duplicate approver in line: %', v_uid USING ERRCODE = '22023';
    END IF;
    v_user_ids := v_user_ids || v_uid;

    IF (v_item->>'stepType') = 'approval' THEN
      v_approval_count := v_approval_count + 1;
    END IF;

    v_group_order := COALESCE((v_item->>'groupOrder')::int, v_index);
    IF v_group_order < 0 THEN
      RAISE EXCEPTION 'groupOrder must be >= 0' USING ERRCODE = '22023';
    END IF;
    v_group_orders := v_group_orders || v_group_order;
    IF v_group_order > v_max_group THEN
      v_max_group := v_group_order;
    END IF;

    v_index := v_index + 1;
  END LOOP;

  IF v_approval_count = 0 THEN
    RAISE EXCEPTION 'At least one approval step required' USING ERRCODE = '22023';
  END IF;

  IF (SELECT count(DISTINCT g) FROM unnest(v_group_orders) AS g) <> v_max_group + 1 THEN
    RAISE EXCEPTION 'groupOrder must be contiguous from 0 (no gaps)' USING ERRCODE = '22023';
  END IF;

  v_group_approval_counts := array_fill(0, ARRAY[v_max_group + 1]);
  v_i := 1;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_group_order := v_group_orders[v_i];
    IF (v_item->>'stepType') = 'approval' THEN
      v_group_approval_counts[v_group_order + 1] :=
        v_group_approval_counts[v_group_order + 1] + 1;
    END IF;
    v_i := v_i + 1;
  END LOOP;
  FOR v_i IN 1..(v_max_group + 1) LOOP
    IF v_group_approval_counts[v_i] = 0 THEN
      RAISE EXCEPTION 'Group % has no approval step', v_i - 1 USING ERRCODE = '22023';
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1 FROM unnest(v_user_ids) AS uid
    WHERE uid NOT IN (
      SELECT user_id FROM public.tenant_members WHERE tenant_id = p_tenant_id
    )
  ) THEN
    RAISE EXCEPTION 'Some approvers are not tenant members' USING ERRCODE = '42501';
  END IF;

  IF array_length(p_attachment_ids, 1) > 0 THEN
    SELECT count(*) INTO v_missing_attachments
    FROM public.approval_attachments
    WHERE id = ANY(p_attachment_ids)
      AND sha256 IS NULL;
    IF v_missing_attachments > 0 THEN
      RAISE EXCEPTION 'Some attachments are missing sha256' USING ERRCODE = '22023';
    END IF;
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
    content, content_hash, drafter_id, status, current_step_index, submitted_at
  )
  VALUES (
    p_tenant_id, v_doc_number, p_form_id, v_schema,
    p_content, p_content_hash, v_user_id, 'pending_post_facto', 0, now()
  )
  RETURNING * INTO v_doc;

  v_index := 0;
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_approval_line) LOOP
    v_step_type := v_item->>'stepType';
    v_uid := (v_item->>'userId')::uuid;
    v_group_order := COALESCE((v_item->>'groupOrder')::int, v_index);
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
      tenant_id, document_id, step_index, group_order, step_type,
      approver_user_id, status, acted_at, comment
    )
    VALUES (
      p_tenant_id, v_doc.id, v_index, v_group_order,
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
          'group_order', v_group_order,
          'original_approver', v_uid,
          'delegate_to', v_delegation_rule.delegate_user_id,
          'rule_id', v_delegation_rule.id,
          'amount', v_amount,
          'post_facto', true
        )
      );
    END IF;

    v_index := v_index + 1;
  END LOOP;

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
      'content_hash', p_content_hash,
      'approval_line', p_approval_line,
      'attachments', p_attachment_ids
    )
  );

  v_doc := public.fn_advance_document(v_doc.id);

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_submit_post_facto(uuid, uuid, jsonb, jsonb, text, text, uuid[])
  TO authenticated;

COMMIT;
