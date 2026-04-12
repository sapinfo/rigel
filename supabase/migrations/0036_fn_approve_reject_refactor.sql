-- 0036_fn_approve_reject_refactor.sql
-- v1.2 M16b: fn_approve_step / fn_reject_step 를 group_order 기반으로 재정의.
-- v1.1 inline "다음 step 탐색" 로직 제거 → PERFORM fn_advance_document.
--
-- 핵심 변경:
--   1. step 탐색 쿼리: step_index = current_step_index
--      → (group_order = current_step_index, approver_user_id = uid, status='pending')
--      병렬 그룹 내 여러 approver 중 본인 step 만 접근.
--   2. 본인 step 없고 proxy 경로 시, 같은 그룹 내 pending approval step 중
--      absence.delegate_user_id = auth.uid() 인 step 탐색.
--      R17: 여러 proxy 후보 시 LIMIT 1 ORDER BY step_index (결정적 1건씩).
--   3. audit payload 에 signature snapshot (storage_path + sha256) 필수 포함.
--      프로필 교체 시에도 승인 시점 증거 보존.
--   4. 승인 후 fn_advance_document 호출 — 그룹 완료 판정 + 전진 or completed.
--   5. reject 는 v1.0 로직 유지 (1건 반려 → 전 pending skipped + doc rejected).

BEGIN;

-- ─── fn_approve_step (병렬 대응 + signature snapshot) ────────

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
  v_absence public.user_absences;
  v_acting_absence public.user_absences;
  v_proxy uuid := NULL;
  v_sig_path text := NULL;
  v_sig_sha256 text := NULL;
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

  IF v_doc.status NOT IN ('in_progress', 'pending_post_facto') THEN
    RAISE EXCEPTION 'Document not actionable (status: %)', v_doc.status USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  -- v1.2 변경: (group_order = current, approver = uid) 조합으로 본인 step 탐색
  SELECT * INTO v_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND group_order = v_doc.current_step_index
    AND approver_user_id = v_user_id
    AND status = 'pending'
    AND step_type = 'approval'
  FOR UPDATE;

  IF v_step.id IS NULL THEN
    -- Proxy 경로: 같은 그룹 내 pending approval step 중 내가 대리인인 것 탐색
    -- R17: 결정적 1건 (step_index 오름차순)
    FOR v_step IN
      SELECT *
      FROM public.approval_steps
      WHERE document_id = p_document_id
        AND group_order = v_doc.current_step_index
        AND status = 'pending'
        AND step_type = 'approval'
      ORDER BY step_index ASC
      FOR UPDATE
    LOOP
      v_absence := public.fn_find_active_absence(
        v_doc.tenant_id,
        v_step.approver_user_id,
        v_doc.form_id
      );

      IF v_absence.id IS NOT NULL AND v_absence.delegate_user_id = v_user_id THEN
        EXIT;  -- 매칭 찾음
      END IF;

      v_step.id := NULL;  -- 루프 종료 시 NULL 체크용
    END LOOP;

    IF v_step.id IS NULL THEN
      RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
    END IF;

    -- 체인 깊이 제한
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

  -- 서명 snapshot (현재 actor 의 profile)
  SELECT signature_storage_path, signature_sha256
    INTO v_sig_path, v_sig_sha256
  FROM public.profiles
  WHERE id = COALESCE(v_proxy, v_user_id);

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload, acted_by_proxy_user_id
  ) VALUES (
    v_doc.tenant_id, v_doc.id,
    COALESCE(v_proxy, v_user_id),
    (CASE WHEN v_proxy IS NULL THEN 'approve' ELSE 'approved_by_proxy' END)::public.audit_action,
    jsonb_build_object(
      'step_index', v_step.step_index,
      'group_order', v_step.group_order,
      'comment', p_comment,
      'original_approver', v_step.approver_user_id,
      'signature_storage_path', v_sig_path,
      'signature_sha256', v_sig_sha256
    ),
    v_proxy
  );

  v_doc := public.fn_advance_document(v_doc.id);

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_approve_step(uuid, text) TO authenticated;

-- ─── fn_reject_step (병렬 대응, 1건 반려 → 전체 rejected) ──

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

  IF v_doc.status NOT IN ('in_progress', 'pending_post_facto') THEN
    RAISE EXCEPTION 'Document not actionable' USING ERRCODE = '22023';
  END IF;

  IF NOT public.is_tenant_member(v_doc.tenant_id) THEN
    RAISE EXCEPTION 'Not a tenant member' USING ERRCODE = '42501';
  END IF;

  SELECT * INTO v_step FROM public.approval_steps
  WHERE document_id = p_document_id
    AND group_order = v_doc.current_step_index
    AND approver_user_id = v_user_id
    AND status = 'pending'
    AND step_type = 'approval'
  FOR UPDATE;

  IF v_step.id IS NULL THEN
    RAISE EXCEPTION 'Not the current approver' USING ERRCODE = '42501';
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
    jsonb_build_object(
      'step_index', v_step.step_index,
      'group_order', v_step.group_order,
      'comment', p_comment
    )
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_reject_step(uuid, text) TO authenticated;

COMMIT;
