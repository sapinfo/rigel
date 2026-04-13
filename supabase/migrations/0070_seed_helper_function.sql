-- seed_create_document: 테스트용 결재 문서 생성 헬퍼
-- seed.sql에서 한 줄 호출로 문서 + 스텝 + 감사로그 생성
-- 프로덕션에서는 사용하지 않음 (SECURITY DEFINER, RLS bypass)

CREATE OR REPLACE FUNCTION public.seed_create_document(
  p_tenant_id uuid,
  p_form_code text,
  p_drafter_id uuid,
  p_title text,
  p_content jsonb DEFAULT '{}'::jsonb,
  p_approvers uuid[] DEFAULT ARRAY[]::uuid[],
  p_target_status text DEFAULT 'draft',
  p_urgency text DEFAULT '일반',
  p_reject_at_step int DEFAULT NULL,
  p_reject_comment text DEFAULT NULL,
  p_step_types text[] DEFAULT NULL,
  p_days_ago int DEFAULT 0
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_doc_id uuid := gen_random_uuid();
  v_form_id uuid;
  v_schema jsonb;
  v_doc_number text;
  v_base_time timestamptz := now() - (p_days_ago || ' days')::interval;
  v_step_count int := array_length(p_approvers, 1);
  v_current_step int := 0;
  v_status document_status := 'draft';
  v_completed_at timestamptz := NULL;
  i int;
  v_step_type step_type;
BEGIN
  SELECT id, schema INTO v_form_id, v_schema
  FROM approval_forms WHERE tenant_id = p_tenant_id AND code = p_form_code;
  IF v_form_id IS NULL THEN
    RAISE EXCEPTION 'Form % not found', p_form_code;
  END IF;

  v_doc_number := 'APP-' || to_char((v_base_time AT TIME ZONE 'Asia/Seoul')::date, 'YYYYMMDD')
    || '-' || lpad((extract(epoch from v_base_time)::int % 9000 + 1000)::text, 4, '0');

  IF p_target_status = 'completed' THEN
    v_status := 'completed'; v_current_step := COALESCE(v_step_count, 0);
    v_completed_at := v_base_time + interval '1 day';
  ELSIF p_target_status = 'rejected' THEN
    v_status := 'rejected'; v_current_step := COALESCE(p_reject_at_step, 0);
  ELSIF p_target_status = 'withdrawn' THEN
    v_status := 'withdrawn'; v_current_step := 0;
  ELSIF p_target_status = 'in_progress' THEN
    v_status := 'in_progress'; v_current_step := GREATEST(COALESCE(v_step_count, 1) - 1, 0);
  END IF;

  INSERT INTO approval_documents (id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, submitted_at, completed_at, urgency, created_at, updated_at)
  VALUES (v_doc_id, p_tenant_id, v_doc_number, v_form_id, v_schema, p_content, p_drafter_id, v_status, v_current_step,
    CASE WHEN p_target_status != 'draft' THEN v_base_time ELSE NULL END, v_completed_at, p_urgency, v_base_time, v_base_time);

  IF p_target_status = 'draft' OR v_step_count IS NULL OR v_step_count = 0 THEN RETURN v_doc_id; END IF;

  INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload, created_at)
  VALUES (p_tenant_id, v_doc_id, p_drafter_id, 'submit', jsonb_build_object('doc_number', v_doc_number), v_base_time);

  FOR i IN 0..(v_step_count - 1) LOOP
    v_step_type := CASE WHEN p_step_types IS NOT NULL AND i < array_length(p_step_types, 1)
      THEN p_step_types[i+1]::step_type ELSE 'approval' END;

    IF p_target_status = 'completed' THEN
      INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, group_order)
      VALUES (p_tenant_id, v_doc_id, i, v_step_type, p_approvers[i+1], 'approved', v_base_time + ((i+1)||' hours')::interval, i);
      INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload, created_at)
      VALUES (p_tenant_id, v_doc_id, p_approvers[i+1], 'approve', jsonb_build_object('step_index', i), v_base_time + ((i+1)||' hours')::interval);

    ELSIF p_target_status = 'rejected' AND i = COALESCE(p_reject_at_step, 0) THEN
      INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, comment, group_order)
      VALUES (p_tenant_id, v_doc_id, i, v_step_type, p_approvers[i+1], 'rejected', v_base_time + interval '6 hours', p_reject_comment, i);
      INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload, created_at)
      VALUES (p_tenant_id, v_doc_id, p_approvers[i+1], 'reject', jsonb_build_object('step_index', i, 'comment', COALESCE(p_reject_comment, '')), v_base_time + interval '6 hours');
      EXIT;

    ELSIF p_target_status = 'rejected' AND i < COALESCE(p_reject_at_step, 0) THEN
      INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, group_order)
      VALUES (p_tenant_id, v_doc_id, i, v_step_type, p_approvers[i+1], 'approved', v_base_time + ((i+1)||' hours')::interval, i);
      INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload, created_at)
      VALUES (p_tenant_id, v_doc_id, p_approvers[i+1], 'approve', jsonb_build_object('step_index', i), v_base_time + ((i+1)||' hours')::interval);

    ELSIF p_target_status = 'withdrawn' THEN
      INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, group_order)
      VALUES (p_tenant_id, v_doc_id, i, v_step_type, p_approvers[i+1], 'skipped', i);

    ELSIF p_target_status = 'in_progress' AND i < v_current_step THEN
      INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, group_order)
      VALUES (p_tenant_id, v_doc_id, i, v_step_type, p_approvers[i+1], 'approved', v_base_time + ((i+1)||' hours')::interval, i);
      INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload, created_at)
      VALUES (p_tenant_id, v_doc_id, p_approvers[i+1], 'approve', jsonb_build_object('step_index', i), v_base_time + ((i+1)||' hours')::interval);

    ELSE
      INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, group_order)
      VALUES (p_tenant_id, v_doc_id, i, v_step_type, p_approvers[i+1], 'pending', i);
    END IF;
  END LOOP;

  IF p_target_status = 'withdrawn' THEN
    INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload, created_at)
    VALUES (p_tenant_id, v_doc_id, p_drafter_id, 'withdraw', '{}'::jsonb, v_base_time + interval '2 hours');
  END IF;

  RETURN v_doc_id;
END;
$$;
