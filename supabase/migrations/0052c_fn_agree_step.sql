-- 0052c: fn_agree_step / fn_disagree_step RPC (v2.2 M4)
-- agreement step 처리. 구조는 fn_approve_step/fn_reject_step과 동일하되 step_type='agreement' 필터.

BEGIN;

-- ─── fn_agree_step ──────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_agree_step(
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
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
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

  -- agreement step 탐색 (같은 그룹, 본인, pending, step_type='agreement')
  SELECT * INTO v_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND group_order = v_doc.current_step_index
    AND approver_user_id = v_user_id
    AND status = 'pending'
    AND step_type = 'agreement'
  FOR UPDATE;

  IF v_step.id IS NULL THEN
    RAISE EXCEPTION 'Not the current agreement approver' USING ERRCODE = '42501';
  END IF;

  UPDATE public.approval_steps
  SET status = 'approved', acted_at = now(), comment = p_comment
  WHERE id = v_step.id;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id,
    'agreed'::public.audit_action,
    jsonb_build_object('step_index', v_step.step_index, 'group_order', v_step.group_order, 'comment', p_comment)
  );

  v_doc := public.fn_advance_document(v_doc.id);
  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_agree_step(uuid, text) TO authenticated;

-- ─── fn_disagree_step ───────────────────────────
CREATE OR REPLACE FUNCTION public.fn_disagree_step(
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
    RAISE EXCEPTION 'Disagree reason required' USING ERRCODE = '22023';
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

  SELECT * INTO v_step
  FROM public.approval_steps
  WHERE document_id = p_document_id
    AND group_order = v_doc.current_step_index
    AND approver_user_id = v_user_id
    AND status = 'pending'
    AND step_type = 'agreement'
  FOR UPDATE;

  IF v_step.id IS NULL THEN
    RAISE EXCEPTION 'Not the current agreement approver' USING ERRCODE = '42501';
  END IF;

  -- 부동의 → 문서 전체 rejected (fn_reject_step과 동일 패턴)
  UPDATE public.approval_steps
  SET status = 'rejected', acted_at = now(), comment = p_comment
  WHERE id = v_step.id;

  -- 나머지 pending steps 전부 skipped
  UPDATE public.approval_steps
  SET status = 'skipped'
  WHERE document_id = p_document_id AND status = 'pending';

  UPDATE public.approval_documents
  SET status = 'rejected', completed_at = now(), updated_at = now()
  WHERE id = p_document_id;

  SELECT * INTO v_doc FROM public.approval_documents WHERE id = p_document_id;

  INSERT INTO public.approval_audit_logs (
    tenant_id, document_id, actor_id, action, payload
  ) VALUES (
    v_doc.tenant_id, v_doc.id, v_user_id,
    'disagreed'::public.audit_action,
    jsonb_build_object('step_index', v_step.step_index, 'group_order', v_step.group_order, 'comment', p_comment)
  );

  RETURN v_doc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_disagree_step(uuid, text) TO authenticated;

COMMIT;
