-- 0075_fn_seed_sample_data.sql
-- 신규 조직 온보딩용 샘플 데이터 생성 RPC.
-- /onboarding/create-tenant 에서 "샘플 데이터 함께 생성" 체크 시 호출.
--
-- 생성 항목:
--   - 부서 3개 (경영지원팀·개발팀·영업팀) — 생성자는 경영지원팀 부장으로 배치
--   - 게시판 2개 (자유게시판·사내 공유) + 샘플 게시글 3개
--   - 공지사항 2개 (일반 1 + 필독 팝업 1)
--   - 회의실 3개 (대회의실·소회의실 A·B)
--   - 근무 시간 설정 (09:00-18:00, 지각 허용 10분)
--
-- 멱등 아님 — 이미 데이터 있을 때 재호출 금지 (onboarding 1회용).
-- 결재 문서는 생성하지 않음 (복잡성 회피, 사용자가 첫 기안으로 체험).

CREATE OR REPLACE FUNCTION public.fn_seed_sample_data(
  p_tenant_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_dept_mgmt uuid;
  v_dept_dev uuid;
  v_dept_sales uuid;
  v_board_free uuid;
  v_board_share uuid;
BEGIN
  -- 권한: 호출자가 해당 tenant의 owner여야 함 (onboarding 맥락)
  IF NOT EXISTS (
    SELECT 1 FROM public.tenant_members
    WHERE tenant_id = p_tenant_id
      AND user_id = v_user_id
      AND role = 'owner'
  ) THEN
    RAISE EXCEPTION 'Only owner can seed sample data' USING ERRCODE = '42501';
  END IF;

  -- ─── 1. 부서 3개 ──────────────────────────────────────
  INSERT INTO public.departments (id, tenant_id, name, parent_id, path)
  VALUES (gen_random_uuid(), p_tenant_id, '경영지원팀', NULL, '/경영지원팀')
  RETURNING id INTO v_dept_mgmt;

  INSERT INTO public.departments (id, tenant_id, name, parent_id, path)
  VALUES (gen_random_uuid(), p_tenant_id, '개발팀', NULL, '/개발팀')
  RETURNING id INTO v_dept_dev;

  INSERT INTO public.departments (id, tenant_id, name, parent_id, path)
  VALUES (gen_random_uuid(), p_tenant_id, '영업팀', NULL, '/영업팀')
  RETURNING id INTO v_dept_sales;

  -- 생성자를 경영지원팀 부장으로 배치
  UPDATE public.tenant_members
  SET department_id = v_dept_mgmt,
      job_title = '부장'
  WHERE tenant_id = p_tenant_id
    AND user_id = v_user_id;

  -- user_departments 에도 primary 지정 (M2M 보강)
  INSERT INTO public.user_departments (tenant_id, user_id, department_id, is_primary)
  VALUES (p_tenant_id, v_user_id, v_dept_mgmt, true)
  ON CONFLICT DO NOTHING;

  -- ─── 2. 게시판 2개 ────────────────────────────────────
  INSERT INTO public.boards (id, tenant_id, name, description, board_type, sort_order, created_by)
  VALUES (gen_random_uuid(), p_tenant_id, '자유게시판', '자유롭게 소통하는 공간', 'general', 1, v_user_id)
  RETURNING id INTO v_board_free;

  INSERT INTO public.boards (id, tenant_id, name, description, board_type, sort_order, created_by)
  VALUES (gen_random_uuid(), p_tenant_id, '사내 공유', '업무 관련 정보 공유', 'general', 2, v_user_id)
  RETURNING id INTO v_board_share;

  -- 샘플 게시글 3개 (자유게시판 2 + 사내공유 1)
  INSERT INTO public.board_posts (board_id, tenant_id, title, content, author_id)
  VALUES
    (v_board_free, p_tenant_id, '환영합니다 👋',
     jsonb_build_object('html', '<p>새로운 Rigel 조직 생성을 축하합니다!</p><p>이 샘플 게시글은 체험용이며, 자유롭게 수정·삭제하셔도 됩니다.</p>'),
     v_user_id),
    (v_board_free, p_tenant_id, '사내 동호회 모집 (풋살)',
     jsonb_build_object('html', '<p>매주 토요일 오전 풋살 동호회를 모집합니다.</p><p>관심 있는 분은 댓글로 알려주세요.</p>'),
     v_user_id),
    (v_board_share, p_tenant_id, '신규 업무 프로세스 안내',
     jsonb_build_object('html', '<p>2026년 1분기부터 적용되는 새 업무 프로세스를 공유합니다.</p><ol><li>기안 → 결재 → 공유</li><li>표준 양식 사용</li></ol>'),
     v_user_id);

  -- ─── 3. 공지사항 2개 ──────────────────────────────────
  INSERT INTO public.announcements (tenant_id, title, content, author_id, is_popup, require_read_confirm, published_at)
  VALUES
    (p_tenant_id, '2026년 연차 사용 가이드',
     jsonb_build_object('html', '<p>2026년 연차는 총 15일이며, 분기별 3일 이상 사용을 권장합니다.</p><p>연차 사용은 휴가신청서 결재로 진행됩니다.</p>'),
     v_user_id, true, true, now()),
    (p_tenant_id, '사무실 정기 청소 일정',
     jsonb_build_object('html', '<p>매주 금요일 오후 6시 이후 정기 청소가 진행됩니다.</p>'),
     v_user_id, false, false, now());

  -- ─── 4. 회의실 3개 ────────────────────────────────────
  INSERT INTO public.meeting_rooms (tenant_id, name, location, capacity, is_active)
  VALUES
    (p_tenant_id, '대회의실', '3층 301호', 20, true),
    (p_tenant_id, '소회의실 A', '2층 205호', 6, true),
    (p_tenant_id, '소회의실 B', '2층 206호', 4, true);

  -- ─── 5. 근무 시간 설정 ────────────────────────────────
  INSERT INTO public.attendance_settings (tenant_id, work_start_time, work_end_time, late_threshold_minutes)
  VALUES (p_tenant_id, '09:00', '18:00', 10)
  ON CONFLICT (tenant_id) DO NOTHING;

END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_seed_sample_data(uuid) TO authenticated;
