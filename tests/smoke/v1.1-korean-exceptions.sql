-- tests/smoke/v1.1-korean-exceptions.sql
--
-- v1.1 잔여 정리 G7: design.md §9 의 S33 / S36 SQL smoke 자동화.
--
-- 실행:
--   psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f tests/smoke/v1.1-korean-exceptions.sql
--
-- 특징:
--   * 단일 TX + 말미 ROLLBACK — DB 상태 불변 (멱등, 반복 실행 안전).
--   * auth.uid() 는 `request.jwt.claim.sub` GUC 로 시뮬레이션 (supabase local 기준).
--   * 필요한 최소 fixture (3명 auth.users + 1개 tenant + 2개 user_absence)만 생성.
--   * published 된 seed form (0014_seed_system_forms.sql, tenant_id IS NULL) 을 재사용.
--
-- 커버 케이스:
--   [S33]  fn_approve_step — proxy chain depth 2 거부
--   [S36a] fn_submit_post_facto — 빈 문자열 reason 거부
--   [S36b] fn_submit_post_facto — NULL reason 거부
--   [S36c] fn_submit_post_facto — whitespace-only reason 거부
--
-- 가정:
--   * `supabase db reset` 이후에 실행 (seed 시스템 양식이 로드된 상태)
--   * postgres 슈퍼유저 권한으로 접속 (BYPASSRLS 기본)
--
-- v1.2 M16b 업데이트: fn_submit_draft / fn_submit_post_facto 가 v3 signature 로 교체되어
--   p_content_hash (64-char hex) 가 필수. S33/S36 모두 placeholder hash 'a' * 64 사용.
--   S36 은 reason 검증이 content_hash 검증보다 앞서므로 hash 순서와 무관.

\set ON_ERROR_STOP on
SET client_min_messages TO NOTICE;

BEGIN;

-- postgres 슈퍼유저지만 명시적으로 RLS off (혹시 모를 대비)
SET LOCAL row_security = off;

-- ─── 1. Fixture 생성 ────────────────────────────────────────

DO $fixture$
DECLARE
  v_tenant uuid := gen_random_uuid();
  v_user_a uuid := gen_random_uuid();  -- drafter / owner
  v_user_b uuid := gen_random_uuid();  -- approver, 부재
  v_user_c uuid := gen_random_uuid();  -- B 의 delegate, 동시 부재
  v_form   uuid;
BEGIN
  -- auth.users: 스키마상 NOT NULL 은 id/is_sso_user/is_anonymous 뿐이지만
  -- handle_new_user() trigger 가 profiles.display_name 을 COALESCE 로 뽑으므로
  -- email 은 반드시 필요 (trigger 의 split_part(email, '@', 1) 소스).
  INSERT INTO auth.users (id, email, is_sso_user, is_anonymous)
  VALUES
    (v_user_a, 'smoke-a@rigel.test', false, false),
    (v_user_b, 'smoke-b@rigel.test', false, false),
    (v_user_c, 'smoke-c@rigel.test', false, false);

  INSERT INTO public.tenants (id, slug, name, owner_id)
  VALUES (v_tenant, 'smoke-v11', 'Smoke v1.1', v_user_a);

  INSERT INTO public.tenant_members (tenant_id, user_id, role) VALUES
    (v_tenant, v_user_a, 'owner'),
    (v_tenant, v_user_b, 'member'),
    (v_tenant, v_user_c, 'member');

  -- 시스템 양식 (tenant_id IS NULL, 0014 에서 seed) 중 published 된 첫 번째 사용
  SELECT id INTO v_form
  FROM public.approval_forms
  WHERE tenant_id IS NULL
    AND is_published = true
  ORDER BY code
  LIMIT 1;

  IF v_form IS NULL THEN
    RAISE EXCEPTION 'smoke setup: no seeded system form — run supabase db reset first';
  END IF;

  -- 체인 깊이 2 fixture: B → C → A 모두 부재.
  -- (실제 v1.1 의 체인 깊이 제한은 1. C 가 승인 시도하면 자기도 부재 → 거부.)
  INSERT INTO public.user_absences (
    tenant_id, user_id, delegate_user_id, absence_type, scope_form_id,
    start_at, end_at, reason
  ) VALUES
    (v_tenant, v_user_b, v_user_c, 'annual', NULL,
     now() - interval '1 day', now() + interval '7 days', 'smoke: B out'),
    (v_tenant, v_user_c, v_user_a, 'annual', NULL,
     now() - interval '1 day', now() + interval '7 days', 'smoke: C out');

  -- 이후 블록들에서 재사용할 id 스태시
  CREATE TEMP TABLE _smoke_ids ON COMMIT DROP AS
  SELECT v_tenant AS tenant, v_user_a AS user_a, v_user_b AS user_b,
         v_user_c AS user_c, v_form AS form;

  RAISE NOTICE 'smoke fixtures created (tenant=%, form=%)', v_tenant, v_form;
END
$fixture$;

-- ─── 2. S36 — fn_submit_post_facto reason 검증 3종 ─────────

DO $s36$
DECLARE
  v record;
  v_err text;
BEGIN
  SELECT * INTO v FROM _smoke_ids;

  -- A 로 로그인한 것처럼 가장 (auth.uid() = A)
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  -- [S36a] 빈 문자열 (reason 검증이 content_hash 검증보다 먼저 발동)
  BEGIN
    PERFORM public.fn_submit_post_facto(
      v.tenant,
      v.form,
      '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
      ),
      repeat('a', 64),  -- v1.2 M16b: content_hash placeholder
      ''                -- empty reason
    );
    RAISE EXCEPTION 'S36a FAIL: RPC unexpectedly succeeded with empty reason';
  EXCEPTION
    WHEN SQLSTATE '22023' THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err <> 'Post-facto reason required' THEN
        RAISE EXCEPTION 'S36a FAIL: expected "Post-facto reason required", got "%"', v_err;
      END IF;
      RAISE NOTICE '[S36a] PASS — empty string reason rejected';
  END;

  -- [S36b] NULL
  BEGIN
    PERFORM public.fn_submit_post_facto(
      v.tenant,
      v.form,
      '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
      ),
      repeat('a', 64),
      NULL
    );
    RAISE EXCEPTION 'S36b FAIL: RPC unexpectedly succeeded with NULL reason';
  EXCEPTION
    WHEN SQLSTATE '22023' THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err <> 'Post-facto reason required' THEN
        RAISE EXCEPTION 'S36b FAIL: expected "Post-facto reason required", got "%"', v_err;
      END IF;
      RAISE NOTICE '[S36b] PASS — NULL reason rejected';
  END;

  -- [S36c] whitespace-only
  BEGIN
    PERFORM public.fn_submit_post_facto(
      v.tenant,
      v.form,
      '{}'::jsonb,
      jsonb_build_array(
        jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
      ),
      repeat('a', 64),
      '   '
    );
    RAISE EXCEPTION 'S36c FAIL: RPC unexpectedly succeeded with whitespace reason';
  EXCEPTION
    WHEN SQLSTATE '22023' THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err <> 'Post-facto reason required' THEN
        RAISE EXCEPTION 'S36c FAIL: expected "Post-facto reason required", got "%"', v_err;
      END IF;
      RAISE NOTICE '[S36c] PASS — whitespace-only reason rejected';
  END;
END
$s36$;

-- ─── 3. S33 — fn_approve_step proxy chain depth 2 거부 ─────

DO $s33$
DECLARE
  v record;
  v_doc public.approval_documents;
  v_err text;
BEGIN
  SELECT * INTO v FROM _smoke_ids;

  -- (a) A 로 draft 상신 — B 가 approver, delegation_rules 없음 → 정상 pending step 생성
  PERFORM set_config('request.jwt.claim.sub', v.user_a::text, true);

  SELECT * INTO v_doc FROM public.fn_submit_draft(
    v.tenant,
    v.form,
    jsonb_build_object('title', 'smoke S33'),
    jsonb_build_array(
      jsonb_build_object('userId', v.user_b::text, 'stepType', 'approval')
    ),
    repeat('a', 64)  -- v1.2 M16b: content_hash placeholder (64-char hex)
  );

  IF v_doc.status <> 'in_progress' THEN
    RAISE EXCEPTION 'S33 setup FAIL: doc.status=% (expected in_progress). delegation_rules 유출?',
      v_doc.status;
  END IF;

  -- (b) C (B 의 delegate, 하지만 C 도 부재 → chain depth 2) 로 전환 후 승인 시도
  PERFORM set_config('request.jwt.claim.sub', v.user_c::text, true);

  BEGIN
    PERFORM public.fn_approve_step(v_doc.id, 'smoke chain approve');
    RAISE EXCEPTION 'S33 FAIL: RPC unexpectedly succeeded. Chain depth 제한이 풀렸는가?';
  EXCEPTION
    WHEN SQLSTATE '22023' THEN
      GET STACKED DIAGNOSTICS v_err = MESSAGE_TEXT;
      IF v_err <> 'Proxy chain depth exceeded' THEN
        RAISE EXCEPTION 'S33 FAIL: expected "Proxy chain depth exceeded", got "%"', v_err;
      END IF;
      RAISE NOTICE '[S33] PASS — chain depth 2 rejected';
  END;
END
$s33$;

-- ─── 4. 완료 리포트 ────────────────────────────────────────

DO $summary$ BEGIN
  RAISE NOTICE '─────────────────────────────────────────────────';
  RAISE NOTICE '✅ v1.1 smoke PASS: S33, S36a, S36b, S36c (4/4)';
  RAISE NOTICE '─────────────────────────────────────────────────';
END $summary$;

ROLLBACK;
