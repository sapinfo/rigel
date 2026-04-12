-- tests/smoke/v1.2-parallel-pdf-hash-signature.sql
--
-- v1.2 smoke: 병렬결재(group_order) / content_hash / delegation+병렬 조합 / 대결+병렬 조합.
-- PDF / 서명 upload 는 별도 수동 검증 (Design §11.2 M1~M7).
--
-- 실행:
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f tests/smoke/v1.2-parallel-pdf-hash-signature.sql
--
-- 특징: 단일 TX + 말미 ROLLBACK (멱등).
--
-- 커버 케이스:
--   S40   순차+병렬 혼합 상신 정상 ([A(0), B(0), C(1), D(2)])
--   S40b  groupOrder gap 금지 검증 ([A(0), B(2)] → RAISE 22023)
--   S40c  각 그룹 ≥ 1 approval step 검증
--   S41   병렬 그룹 1건 반려 → 전체 rejected
--   S42   병렬 그룹 내 delegation 1건 skip → 나머지 pending 유지
--   S42b  이후 나머지 approve → group 완료, next group 전진
--   S43   병렬 그룹 내 대결 (proxy approval)
--   S44   전 그룹 approve → document completed
--   S45   content_hash NOT NULL 강제 검증 (NULL / 잘못된 길이 / 잘못된 형식)
--   S46   attachment sha256 NULL 검증

\set ON_ERROR_STOP on
SET client_min_messages TO NOTICE;

BEGIN;

SET LOCAL row_security = off;

-- ─── 1. Fixture ────────────────────────────────────────────

DO $fixture$
DECLARE
  v_tenant uuid := gen_random_uuid();
  v_user_a uuid := gen_random_uuid();  -- drafter + owner
  v_user_b uuid := gen_random_uuid();
  v_user_c uuid := gen_random_uuid();
  v_user_d uuid := gen_random_uuid();
  v_user_e uuid := gen_random_uuid();  -- delegation target (for S42)
  v_user_x uuid := gen_random_uuid();  -- absence delegate (for S43)
  v_form uuid;
BEGIN
  INSERT INTO auth.users (id, email, is_sso_user, is_anonymous) VALUES
    (v_user_a, 'v12-a@rigel.test', false, false),
    (v_user_b, 'v12-b@rigel.test', false, false),
    (v_user_c, 'v12-c@rigel.test', false, false),
    (v_user_d, 'v12-d@rigel.test', false, false),
    (v_user_e, 'v12-e@rigel.test', false, false),
    (v_user_x, 'v12-x@rigel.test', false, false);

  INSERT INTO public.tenants (id, slug, name, owner_id)
  VALUES (v_tenant, 'smoke-v12', 'Smoke v1.2', v_user_a);

  INSERT INTO public.tenant_members (tenant_id, user_id, role) VALUES
    (v_tenant, v_user_a, 'owner'),
    (v_tenant, v_user_b, 'member'),
    (v_tenant, v_user_c, 'member'),
    (v_tenant, v_user_d, 'member'),
    (v_tenant, v_user_e, 'member'),
    (v_tenant, v_user_x, 'member');

  -- 시스템 seed form 사용
  SELECT id INTO v_form
  FROM public.approval_forms
  WHERE tenant_id IS NULL AND is_published = true
  ORDER BY code
  LIMIT 1;

  IF v_form IS NULL THEN
    RAISE EXCEPTION 'smoke setup: no seeded system form — run supabase db reset first';
  END IF;

  CREATE TEMP TABLE _v12_ids ON COMMIT DROP AS
  SELECT v_tenant AS tenant,
         v_user_a AS user_a, v_user_b AS user_b, v_user_c AS user_c,
         v_user_d AS user_d, v_user_e AS user_e, v_user_x AS user_x,
         v_form AS form;

  RAISE NOTICE 'v1.2 smoke fixtures created';
END
$fixture$;

-- ─── 2. S40 — 순차+병렬 혼합 상신 정상 ─────────────────────

DO $s40$
DECLARE
  v record;
  v_doc public.approval_documents;
  v_steps_count int;
  v_group_counts int[];
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  SELECT * INTO v_doc FROM public.fn_submit_draft(
    v.tenant,
    v.form,
    jsonb_build_object('title', 'S40 parallel mixed'),
    jsonb_build_array(
      jsonb_build_object('userId', v.user_a::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_c::text, 'stepType', 'approval', 'groupOrder', 1),
      jsonb_build_object('userId', v.user_d::text, 'stepType', 'approval', 'groupOrder', 2)
    ),
    repeat('b', 64)
  );

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'S40 FAIL: doc.status=% (expected in_progress)', v_doc.status;
  END IF;
  IF v_doc.current_step_index <> 0 THEN
    RAISE EXCEPTION 'S40 FAIL: current_step_index=% (expected 0)', v_doc.current_step_index;
  END IF;
  IF v_doc.content_hash <> repeat('b', 64) THEN
    RAISE EXCEPTION 'S40 FAIL: content_hash not stored';
  END IF;

  -- 4 steps with group_order = {0,0,1,2}
  SELECT count(*) INTO v_steps_count
  FROM public.approval_steps
  WHERE document_id = v_doc.id;

  IF v_steps_count <> 4 THEN
    RAISE EXCEPTION 'S40 FAIL: expected 4 steps, got %', v_steps_count;
  END IF;

  SELECT array_agg(group_order ORDER BY step_index) INTO v_group_counts
  FROM public.approval_steps
  WHERE document_id = v_doc.id;

  IF v_group_counts <> ARRAY[0,0,1,2] THEN
    RAISE EXCEPTION 'S40 FAIL: group_order array % (expected {0,0,1,2})', v_group_counts;
  END IF;

  RAISE NOTICE '[S40] PASS — 순차+병렬 혼합 상신 정상 (4 steps, group_order={0,0,1,2})';

  -- 뒤 테스트 위해 cleanup (rollback 까진 유지되지만 명확성)
  DELETE FROM public.approval_audit_logs WHERE document_id = v_doc.id;
  DELETE FROM public.approval_steps WHERE document_id = v_doc.id;
  DELETE FROM public.approval_documents WHERE id = v_doc.id;
END
$s40$;

-- ─── 3. S40b — groupOrder gap 금지 ─────────────────────────

DO $s40b$
DECLARE
  v record;
  v_err text;
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  BEGIN
    PERFORM public.fn_submit_draft(
      v.tenant,
      v.form,
      '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_a::text, 'stepType', 'approval', 'groupOrder', 0),
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval', 'groupOrder', 2)
      ),
      repeat('c', 64)
    );
    RAISE EXCEPTION 'S40b FAIL: expected groupOrder gap error';
  EXCEPTION
    WHEN SQLSTATE '22023' THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err NOT LIKE '%groupOrder must be contiguous%' THEN
        RAISE EXCEPTION 'S40b FAIL: got "%"', v_err;
      END IF;
      RAISE NOTICE '[S40b] PASS — groupOrder gap rejected';
  END;
END
$s40b$;

-- ─── 4. S40c — 각 그룹 ≥ 1 approval 검증 ──────────────────

DO $s40c$
DECLARE
  v record;
  v_err text;
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  -- 그룹 0 에 reference 만 있는 경우
  BEGIN
    PERFORM public.fn_submit_draft(
      v.tenant,
      v.form,
      '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_a::text, 'stepType', 'reference', 'groupOrder', 0),
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval', 'groupOrder', 1)
      ),
      repeat('c', 64)
    );
    RAISE EXCEPTION 'S40c FAIL: expected group 0 has no approval error';
  EXCEPTION
    WHEN SQLSTATE '22023' THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err NOT LIKE 'Group % has no approval step' THEN
        RAISE EXCEPTION 'S40c FAIL: got "%"', v_err;
      END IF;
      RAISE NOTICE '[S40c] PASS — empty group rejected: %', v_err;
  END;
END
$s40c$;

-- ─── 5. S41 — 병렬 그룹 1건 반려 → 전체 rejected ─────────

DO $s41$
DECLARE
  v record;
  v_doc public.approval_documents;
  v_rejected_count int;
  v_skipped_count int;
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  -- 상신 — 그룹 0 에 A, B 병렬; 그룹 1 에 C
  SELECT * INTO v_doc FROM public.fn_submit_draft(
    v.tenant,
    v.form,
    jsonb_build_object('title', 'S41 reject'),
    jsonb_build_array(
      jsonb_build_object('userId', v.user_a::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_c::text, 'stepType', 'approval', 'groupOrder', 1)
    ),
    repeat('d', 64)
  );

  -- A 가 approve
  PERFORM public.fn_approve_step(v_doc.id, 'S41 A ok');

  -- B 가 reject
  PERFORM set_config('request.jwt.claim.sub', v.user_b::text, true);
  PERFORM public.fn_reject_step(v_doc.id, 'S41 B reject');

  -- document 는 rejected
  SELECT * INTO v_doc FROM public.approval_documents WHERE id = v_doc.id;
  IF v_doc.status <> 'rejected' THEN
    RAISE EXCEPTION 'S41 FAIL: doc status=% (expected rejected)', v_doc.status;
  END IF;

  -- B step = rejected, C step = skipped (A 는 이미 approved)
  SELECT count(*) INTO v_rejected_count
  FROM public.approval_steps
  WHERE document_id = v_doc.id AND status = 'rejected';
  SELECT count(*) INTO v_skipped_count
  FROM public.approval_steps
  WHERE document_id = v_doc.id AND status = 'skipped';

  IF v_rejected_count <> 1 OR v_skipped_count <> 1 THEN
    RAISE EXCEPTION 'S41 FAIL: rejected=%, skipped=% (expected 1, 1)',
      v_rejected_count, v_skipped_count;
  END IF;

  RAISE NOTICE '[S41] PASS — 병렬 그룹 1건 반려 → 전체 rejected, 나머지 skipped';

  DELETE FROM public.approval_audit_logs WHERE document_id = v_doc.id;
  DELETE FROM public.approval_steps WHERE document_id = v_doc.id;
  DELETE FROM public.approval_documents WHERE id = v_doc.id;
END
$s41$;

-- ─── 6. S42 — 병렬 그룹 내 delegation 1건 skip, 나머지 pending ─

DO $s42$
DECLARE
  v record;
  v_doc public.approval_documents;
  v_a_status public.step_status;
  v_b_status public.step_status;
  v_delegation_id uuid;
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  -- A → E delegation rule
  INSERT INTO public.delegation_rules (
    tenant_id, delegator_user_id, delegate_user_id, form_id,
    amount_limit, effective_from, effective_to, created_by
  ) VALUES (
    v.tenant, v.user_a, v.user_e, NULL, NULL,
    now() - interval '1 day', NULL, v.user_a
  ) RETURNING id INTO v_delegation_id;

  -- 상신 — 그룹 0 에 A, B 병렬. A 는 delegation 매칭으로 skip 될 예정
  SELECT * INTO v_doc FROM public.fn_submit_draft(
    v.tenant,
    v.form,
    '{}'::jsonb,
    jsonb_build_array(
      jsonb_build_object('userId', v.user_a::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_c::text, 'stepType', 'approval', 'groupOrder', 1)
    ),
    repeat('e', 64)
  );

  SELECT status INTO v_a_status FROM public.approval_steps
  WHERE document_id = v_doc.id AND approver_user_id = v.user_a;
  SELECT status INTO v_b_status FROM public.approval_steps
  WHERE document_id = v_doc.id AND approver_user_id = v.user_b;

  IF v_a_status <> 'skipped' THEN
    RAISE EXCEPTION 'S42 FAIL: A.status=% (expected skipped)', v_a_status;
  END IF;
  IF v_b_status <> 'pending' THEN
    RAISE EXCEPTION 'S42 FAIL: B.status=% (expected pending)', v_b_status;
  END IF;
  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'S42 FAIL: doc status=% (expected in_progress, B 미완)', v_doc.status;
  END IF;
  IF v_doc.current_step_index <> 0 THEN
    RAISE EXCEPTION 'S42 FAIL: current_step_index=% (expected 0, B 아직 pending)', v_doc.current_step_index;
  END IF;

  RAISE NOTICE '[S42] PASS — 병렬 내 delegation 1건 skip, 그룹 0 유지';

  -- S42b — 이어서 B approve → group 1 로 전진
  PERFORM set_config('request.jwt.claim.sub', v.user_b::text, true);
  v_doc := public.fn_approve_step(v_doc.id, 'S42b B approve');

  IF v_doc.current_step_index <> 1 THEN
    RAISE EXCEPTION 'S42b FAIL: current_step_index=% (expected 1)', v_doc.current_step_index;
  END IF;
  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'S42b FAIL: doc status=% (expected in_progress)', v_doc.status;
  END IF;

  RAISE NOTICE '[S42b] PASS — B approve → group 1 전진';

  -- cleanup
  DELETE FROM public.approval_audit_logs WHERE document_id = v_doc.id;
  DELETE FROM public.approval_steps WHERE document_id = v_doc.id;
  DELETE FROM public.approval_documents WHERE id = v_doc.id;
  DELETE FROM public.delegation_rules WHERE id = v_delegation_id;
END
$s42$;

-- ─── 7. S43 — 병렬 그룹 내 대결 (proxy approval) ─────────

DO $s43$
DECLARE
  v record;
  v_doc public.approval_documents;
  v_a_step public.approval_steps;
  v_absence_id uuid;
  v_payload jsonb;
BEGIN
  SELECT * INTO v FROM _v12_ids;

  -- A 부재 → X 가 대리
  INSERT INTO public.user_absences (
    tenant_id, user_id, delegate_user_id, absence_type,
    scope_form_id, start_at, end_at
  ) VALUES (
    v.tenant, v.user_a, v.user_x, 'annual',
    NULL, now() - interval '1 day', now() + interval '7 days'
  ) RETURNING id INTO v_absence_id;

  -- 서명 snapshot 준비 (X 에게 서명 등록)
  UPDATE public.profiles
  SET signature_storage_path = v.user_x::text || '/signature.png',
      signature_sha256 = repeat('7', 64)
  WHERE id = v.user_x;

  -- 상신 (B 가 drafter 라 X 와 충돌 없음)
  PERFORM set_config('request.jwt.claim.sub', v.user_b::text, true);
  SELECT * INTO v_doc FROM public.fn_submit_draft(
    v.tenant,
    v.form,
    '{}'::jsonb,
    jsonb_build_array(
      jsonb_build_object('userId', v.user_a::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_c::text, 'stepType', 'approval', 'groupOrder', 0)
    ),
    repeat('f', 64)
  );

  -- X 가 A 대리로 승인 (proxy 경로)
  PERFORM set_config('request.jwt.claim.sub', v.user_x::text, true);
  PERFORM public.fn_approve_step(v_doc.id, 'S43 proxy approve');

  SELECT * INTO v_a_step
  FROM public.approval_steps
  WHERE document_id = v_doc.id AND approver_user_id = v.user_a;

  IF v_a_step.status <> 'approved' THEN
    RAISE EXCEPTION 'S43 FAIL: A step status=% (expected approved)', v_a_step.status;
  END IF;
  IF v_a_step.acted_by_proxy_user_id <> v.user_x THEN
    RAISE EXCEPTION 'S43 FAIL: acted_by_proxy=% (expected X)', v_a_step.acted_by_proxy_user_id;
  END IF;

  -- audit payload 에 signature snapshot 확인
  SELECT payload INTO v_payload
  FROM public.approval_audit_logs
  WHERE document_id = v_doc.id AND action = 'approved_by_proxy'
  ORDER BY created_at DESC LIMIT 1;

  IF v_payload->>'signature_storage_path' <> v.user_x::text || '/signature.png' THEN
    RAISE EXCEPTION 'S43 FAIL: signature_storage_path snapshot missing/wrong: %',
      v_payload->>'signature_storage_path';
  END IF;
  IF v_payload->>'signature_sha256' <> repeat('7', 64) THEN
    RAISE EXCEPTION 'S43 FAIL: signature_sha256 snapshot wrong';
  END IF;

  -- document 는 C 가 아직 pending 이므로 in_progress 유지
  SELECT * INTO v_doc FROM public.approval_documents WHERE id = v_doc.id;
  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'S43 FAIL: doc status=% (expected in_progress — C 아직 pending)', v_doc.status;
  END IF;

  RAISE NOTICE '[S43] PASS — 병렬 내 proxy approval + signature snapshot';

  DELETE FROM public.approval_audit_logs WHERE document_id = v_doc.id;
  DELETE FROM public.approval_steps WHERE document_id = v_doc.id;
  DELETE FROM public.approval_documents WHERE id = v_doc.id;
  DELETE FROM public.user_absences WHERE id = v_absence_id;
  UPDATE public.profiles
  SET signature_storage_path = NULL, signature_sha256 = NULL
  WHERE id = v.user_x;
END
$s43$;

-- ─── 8. S44 — 전 그룹 approve → completed ────────────────

DO $s44$
DECLARE
  v record;
  v_doc public.approval_documents;
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  -- 순차 3건 (그룹 0, 1, 2)
  SELECT * INTO v_doc FROM public.fn_submit_draft(
    v.tenant,
    v.form,
    '{}'::jsonb,
    jsonb_build_array(
      jsonb_build_object('userId', v.user_a::text, 'stepType', 'approval', 'groupOrder', 0),
      jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval', 'groupOrder', 1),
      jsonb_build_object('userId', v.user_c::text, 'stepType', 'approval', 'groupOrder', 2)
    ),
    repeat('9', 64)
  );

  -- A approve
  PERFORM public.fn_approve_step(v_doc.id, 'A ok');
  -- B approve
  PERFORM set_config('request.jwt.claim.sub', v.user_b::text, true);
  PERFORM public.fn_approve_step(v_doc.id, 'B ok');
  -- C approve (최종)
  PERFORM set_config('request.jwt.claim.sub', v.user_c::text, true);
  v_doc := public.fn_approve_step(v_doc.id, 'C ok');

  IF v_doc.status <> 'completed' THEN
    RAISE EXCEPTION 'S44 FAIL: doc.status=% (expected completed)', v_doc.status;
  END IF;
  IF v_doc.completed_at IS NULL THEN
    RAISE EXCEPTION 'S44 FAIL: completed_at is NULL';
  END IF;

  RAISE NOTICE '[S44] PASS — 전 그룹 approve → completed';

  DELETE FROM public.approval_audit_logs WHERE document_id = v_doc.id;
  DELETE FROM public.approval_steps WHERE document_id = v_doc.id;
  DELETE FROM public.approval_documents WHERE id = v_doc.id;
END
$s44$;

-- ─── 9. S45 — content_hash 검증 (NULL / length / format) ──

DO $s45$
DECLARE
  v record;
  v_err text;
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  -- NULL
  BEGIN
    PERFORM public.fn_submit_draft(
      v.tenant, v.form, '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
      ),
      NULL
    );
    RAISE EXCEPTION 'S45a FAIL: expected content_hash NULL rejection';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err NOT LIKE 'Invalid content_hash%' THEN
      RAISE EXCEPTION 'S45a FAIL: got "%"', v_err;
    END IF;
  END;

  -- 길이 부족
  BEGIN
    PERFORM public.fn_submit_draft(
      v.tenant, v.form, '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
      ),
      'abc'
    );
    RAISE EXCEPTION 'S45b FAIL: expected length rejection';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err NOT LIKE 'Invalid content_hash%' THEN
      RAISE EXCEPTION 'S45b FAIL: got "%"', v_err;
    END IF;
  END;

  -- non-hex 문자 (길이는 64 지만 'Z' 포함)
  BEGIN
    PERFORM public.fn_submit_draft(
      v.tenant, v.form, '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
      ),
      'Z' || repeat('a', 63)
    );
    RAISE EXCEPTION 'S45c FAIL: expected format rejection';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err NOT LIKE 'Invalid content_hash format%' THEN
      RAISE EXCEPTION 'S45c FAIL: got "%"', v_err;
    END IF;
  END;

  RAISE NOTICE '[S45] PASS — content_hash NULL/length/format rejected (3/3)';
END
$s45$;

-- ─── 10. S46 — attachment sha256 NULL 검증 ───────────────

DO $s46$
DECLARE
  v record;
  v_err text;
  v_att_id uuid;
BEGIN
  SELECT * INTO v FROM _v12_ids;
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  -- sha256 NULL 인 attachment 생성
  INSERT INTO public.approval_attachments (
    tenant_id, storage_path, file_name, mime, size, uploaded_by
  ) VALUES (
    v.tenant, 'v12-test/x.pdf', 'x.pdf', 'application/pdf', 100, v.user_a
  ) RETURNING id INTO v_att_id;

  BEGIN
    PERFORM public.fn_submit_draft(
      v.tenant, v.form, '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
      ),
      repeat('a', 64),
      ARRAY[v_att_id]
    );
    RAISE EXCEPTION 'S46 FAIL: expected attachment sha256 NULL rejection';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
    IF v_err <> 'Some attachments are missing sha256' THEN
      RAISE EXCEPTION 'S46 FAIL: got "%"', v_err;
    END IF;
    RAISE NOTICE '[S46] PASS — attachment sha256 NULL rejected';
  END;
END
$s46$;

-- ─── 11. Summary ───────────────────────────────────────────

DO $summary$ BEGIN
  RAISE NOTICE '─────────────────────────────────────────────────';
  RAISE NOTICE '✅ v1.2 smoke PASS: S40, S40b, S40c, S41, S42, S42b, S43, S44, S45, S46 (10/10)';
  RAISE NOTICE '─────────────────────────────────────────────────';
END $summary$;

ROLLBACK;
