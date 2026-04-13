-- ============================================================
-- Rigel 테스트 seed 데이터
-- supabase start 시 migration 적용 후 자동 실행
-- ============================================================

-- ─── 1. 테스트 계정 (auth.users) ─────────────────────────
-- CLAUDE.md 기준 계정. password = testpass1234
-- confirmation_token 등 모든 token 필드 '' (NULL이면 GoTrue 실패)

INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, confirmation_token, recovery_token,
  email_change_token_new, email_change,
  raw_app_meta_data, raw_user_meta_data,
  aud, role, created_at, updated_at
) VALUES
-- m3test1@example.com (owner of m3test-org)
(
  'a0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'm3test1@example.com',
  crypt('testpass1234', gen_salt('bf', 10)),
  now(), '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"테스트관리자"}'::jsonb,
  'authenticated', 'authenticated', now(), now()
),
-- m5approver@example.com (member of m3test-org)
(
  'a0000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'm5approver@example.com',
  crypt('testpass1234', gen_salt('bf', 10)),
  now(), '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"결재자"}'::jsonb,
  'authenticated', 'authenticated', now(), now()
),
-- newuser@example.com (member of m3test-org)
(
  'a0000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'newuser@example.com',
  crypt('testpass1234', gen_salt('bf', 10)),
  now(), '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"신규사용자"}'::jsonb,
  'authenticated', 'authenticated', now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- auth.identities (GoTrue 필수)
INSERT INTO auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
) VALUES
(
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'm3test1@example.com', 'email',
  '{"sub":"a0000000-0000-0000-0000-000000000001","email":"m3test1@example.com"}'::jsonb,
  now(), now(), now()
),
(
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000002',
  'm5approver@example.com', 'email',
  '{"sub":"a0000000-0000-0000-0000-000000000002","email":"m5approver@example.com"}'::jsonb,
  now(), now(), now()
),
(
  'a0000000-0000-0000-0000-000000000003',
  'a0000000-0000-0000-0000-000000000003',
  'newuser@example.com', 'email',
  '{"sub":"a0000000-0000-0000-0000-000000000003","email":"newuser@example.com"}'::jsonb,
  now(), now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- ─── 2. 테넌트 ──────────────────────────────────────────

INSERT INTO public.tenants (id, slug, name, owner_id)
VALUES (
  'b0000000-0000-0000-0000-000000000001',
  'm3test-org',
  'M3 테스트 조직',
  'a0000000-0000-0000-0000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

-- ─── 3. 멤버십 ──────────────────────────────────────────

INSERT INTO public.tenant_members (tenant_id, user_id, role) VALUES
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'owner'),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'member'),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'member')
ON CONFLICT (tenant_id, user_id) DO NOTHING;

-- ─── 4. profiles default_tenant 설정 ─────────────────────

UPDATE public.profiles
SET default_tenant_id = 'b0000000-0000-0000-0000-000000000001'
WHERE id IN (
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003'
);

-- ─── 5. 부서 ─────────────────────────────────────────────

INSERT INTO public.departments (id, tenant_id, name, parent_id, path) VALUES
('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '경영지원팀', NULL, '/경영지원팀'),
('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', '개발팀', NULL, '/개발팀'),
('d0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', '영업팀', NULL, '/영업팀')
ON CONFLICT (id) DO NOTHING;

-- user_departments
INSERT INTO public.user_departments (tenant_id, user_id, department_id, is_primary) VALUES
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', true),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', true),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000003', true)
ON CONFLICT (tenant_id, user_id, department_id) DO NOTHING;

-- ─── 6. 시스템 양식 → 테넌트 복사 ─────────────────────────

SELECT public.fn_copy_system_forms('b0000000-0000-0000-0000-000000000001');

-- ─── 7. 근무 설정 (기본값) ────────────────────────────────

INSERT INTO public.attendance_settings (tenant_id)
VALUES ('b0000000-0000-0000-0000-000000000001')
ON CONFLICT (tenant_id) DO NOTHING;

-- ─── 8. 직급 체계 ────────────────────────────────────────

INSERT INTO public.job_titles (id, tenant_id, name, level) VALUES
('e0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '사원', 1),
('e0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', '대리', 2),
('e0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', '과장', 3),
('e0000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', '차장', 4),
('e0000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', '부장', 5),
('e0000000-0000-0000-0000-000000000006', 'b0000000-0000-0000-0000-000000000001', '이사', 6)
ON CONFLICT (tenant_id, name) DO NOTHING;

-- 멤버에 직급 연결
UPDATE public.tenant_members SET job_title_id = 'e0000000-0000-0000-0000-000000000005'
WHERE tenant_id = 'b0000000-0000-0000-0000-000000000001' AND user_id = 'a0000000-0000-0000-0000-000000000001';
UPDATE public.tenant_members SET job_title_id = 'e0000000-0000-0000-0000-000000000003'
WHERE tenant_id = 'b0000000-0000-0000-0000-000000000001' AND user_id = 'a0000000-0000-0000-0000-000000000002';
UPDATE public.tenant_members SET job_title_id = 'e0000000-0000-0000-0000-000000000001'
WHERE tenant_id = 'b0000000-0000-0000-0000-000000000001' AND user_id = 'a0000000-0000-0000-0000-000000000003';

-- ─── 9. 인사 프로필 ──────────────────────────────────────

INSERT INTO public.employee_profiles (user_id, tenant_id, employee_number, hire_date, phone_mobile, job_title, job_position) VALUES
('a0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'EMP-001', '2020-03-02', '010-1234-5678', '팀장', '부장'),
('a0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'EMP-002', '2022-07-15', '010-2345-6789', NULL, '과장'),
('a0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'EMP-003', '2025-01-06', '010-3456-7890', NULL, '사원')
ON CONFLICT (user_id) DO NOTHING;

-- ─── 10. 게시판 ──────────────────────────────────────────

INSERT INTO public.boards (id, tenant_id, name, description, board_type, department_id, sort_order, created_by) VALUES
('c1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '자유게시판', '자유롭게 소통하는 공간', 'general', NULL, 1, 'a0000000-0000-0000-0000-000000000001'),
('c1000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', '사내 공유', '업무 관련 정보 공유', 'general', NULL, 2, 'a0000000-0000-0000-0000-000000000001'),
('c1000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', '개발팀 게시판', '개발팀 내부 소통', 'department', 'd0000000-0000-0000-0000-000000000002', 3, 'a0000000-0000-0000-0000-000000000001')
ON CONFLICT (id) DO NOTHING;

-- ─── 11. 게시글 ──────────────────────────────────────────

INSERT INTO public.board_posts (id, board_id, tenant_id, title, content, author_id, is_pinned, view_count) VALUES
-- 자유게시판
('c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 '4월 회식 장소 추천 받습니다', '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"이번 달 회식 장소 추천해주세요! 강남역 근처면 좋겠습니다."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000003', false, 12),
('c2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 '사내 동호회 모집 (풋살)', '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"풋살 동호회를 만들려고 합니다. 관심 있으신 분은 댓글 남겨주세요."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000002', false, 8),
-- 사내 공유 (공지 고정)
('c2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
 '[필독] 2026년 연차 사용 가이드', '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"2026년 연차 사용 기준이 변경되었습니다. 상반기 내 50% 이상 소진 권장합니다."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000001', true, 45),
('c2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
 '신규 업무 프로세스 안내', '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"4월부터 결재 프로세스가 변경됩니다. Rigel 시스템을 통해 모든 결재를 진행해주세요."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000001', false, 23),
-- 개발팀 게시판
('c2000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001',
 'Sprint 14 회고', '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"이번 스프린트에서 잘한 점과 개선할 점을 정리합니다."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000002', false, 5)
ON CONFLICT (id) DO NOTHING;

-- ─── 12. 댓글 ────────────────────────────────────────────

INSERT INTO public.board_comments (id, post_id, tenant_id, author_id, content) VALUES
('c3000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 'a0000000-0000-0000-0000-000000000002', '역삼동 고기집 어떨까요?'),
('c3000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 'a0000000-0000-0000-0000-000000000001', '좋습니다! 예약해주세요.'),
('c3000000-0000-0000-0000-000000000003', 'c2000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
 'a0000000-0000-0000-0000-000000000003', '저도 참여하고 싶습니다!'),
('c3000000-0000-0000-0000-000000000004', 'c2000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001',
 'a0000000-0000-0000-0000-000000000002', '다음 스프린트에는 코드리뷰 시간을 더 확보하면 좋겠습니다.')
ON CONFLICT (id) DO NOTHING;

-- ─── 13. 공지사항 ────────────────────────────────────────

INSERT INTO public.announcements (id, tenant_id, title, content, author_id, is_popup, require_read_confirm, published_at, expires_at) VALUES
-- 필독 + 팝업 공지
('c4000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 '개인정보 보호 교육 안내 (필수 이수)',
 '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"전 직원 대상 개인정보 보호 교육을 4월 말까지 이수해주세요. 미이수 시 인사 불이익이 있을 수 있습니다."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000001', true, true,
 now() - interval '2 days', now() + interval '30 days'),
-- 일반 공지
('c4000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
 '4월 급여 지급일 안내',
 '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"4월 급여는 4월 25일(금)에 지급됩니다. 통장 확인 부탁드립니다."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000001', false, false,
 now() - interval '1 day', NULL),
-- 만료된 공지
('c4000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001',
 '서버 점검 안내 (완료)',
 '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"3월 30일 서버 점검이 완료되었습니다."}]}]}'::jsonb,
 'a0000000-0000-0000-0000-000000000001', false, false,
 now() - interval '14 days', now() - interval '7 days')
ON CONFLICT (id) DO NOTHING;

-- ─── 14. 회의실 ──────────────────────────────────────────

INSERT INTO public.meeting_rooms (id, tenant_id, name, location, capacity) VALUES
('c5000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '대회의실', '3층 301호', 20),
('c5000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', '소회의실 A', '2층 205호', 6),
('c5000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', '소회의실 B', '2층 206호', 4)
ON CONFLICT (id) DO NOTHING;

-- ─── 15. 회의실 예약 ─────────────────────────────────────

INSERT INTO public.room_reservations (id, room_id, tenant_id, title, reserved_by, start_at, end_at) VALUES
('c6000000-0000-0000-0000-000000000001', 'c5000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 '주간 전체 회의', 'a0000000-0000-0000-0000-000000000001',
 (current_date + interval '1 day')::date + time '10:00', (current_date + interval '1 day')::date + time '11:00'),
('c6000000-0000-0000-0000-000000000002', 'c5000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
 '개발팀 스프린트 플래닝', 'a0000000-0000-0000-0000-000000000002',
 (current_date + interval '1 day')::date + time '14:00', (current_date + interval '1 day')::date + time '15:30')
ON CONFLICT (id) DO NOTHING;

-- ─── 16. 캘린더 일정 ─────────────────────────────────────

INSERT INTO public.calendar_events (id, tenant_id, title, description, start_at, end_at, all_day, event_type, department_id, created_by, color) VALUES
-- 전사 일정
('c7000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001',
 '2026 상반기 워크숍', '전 직원 참석 필수',
 (current_date + interval '7 days')::date + time '09:00', (current_date + interval '7 days')::date + time '18:00',
 false, 'company', NULL, 'a0000000-0000-0000-0000-000000000001', '#3b82f6'),
-- 부서 일정
('c7000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001',
 '개발팀 코드리뷰 데이', NULL,
 (current_date + interval '2 days')::date + time '14:00', (current_date + interval '2 days')::date + time '17:00',
 false, 'department', 'd0000000-0000-0000-0000-000000000002', 'a0000000-0000-0000-0000-000000000002', '#10b981'),
-- 개인 일정
('c7000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001',
 '치과 예약', NULL,
 (current_date + interval '3 days')::date + time '11:00', (current_date + interval '3 days')::date + time '12:00',
 false, 'personal', NULL, 'a0000000-0000-0000-0000-000000000003', '#f59e0b'),
-- 종일 일정
('c7000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001',
 '창립기념일', '회사 창립 10주년',
 (current_date + interval '14 days')::date, (current_date + interval '14 days')::date + time '23:59',
 true, 'company', NULL, 'a0000000-0000-0000-0000-000000000001', '#ef4444')
ON CONFLICT (id) DO NOTHING;

-- ─── 17. 출퇴근 기록 (지난 며칠) ─────────────────────────

INSERT INTO public.attendance_records (id, tenant_id, user_id, work_date, clock_in, clock_out, work_type) VALUES
-- 테스트관리자 최근 3일
('c8000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
 current_date - 3, (current_date - 3)::date + time '08:55', (current_date - 3)::date + time '18:10', 'normal'),
('c8000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
 current_date - 2, (current_date - 2)::date + time '09:05', (current_date - 2)::date + time '18:30', 'normal'),
('c8000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001',
 current_date - 1, (current_date - 1)::date + time '09:25', (current_date - 1)::date + time '19:00', 'late'),
-- 결재자 최근 2일
('c8000000-0000-0000-0000-000000000004', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002',
 current_date - 2, (current_date - 2)::date + time '08:45', (current_date - 2)::date + time '17:50', 'normal'),
('c8000000-0000-0000-0000-000000000005', 'b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002',
 current_date - 1, (current_date - 1)::date + time '09:00', (current_date - 1)::date + time '18:00', 'normal')
ON CONFLICT (tenant_id, user_id, work_date) DO NOTHING;

-- ============================================================
-- 18~22. 결재 문서 샘플 (다양한 상태)
-- form_id는 fn_copy_system_forms가 동적 생성하므로 서브쿼리로 참조
-- seed.sql은 postgres 슈퍼유저로 실행 → RLS(ad_no_direct_insert) 우회
-- ============================================================

-- 변수 대용: 양식 ID를 임시 테이블에 저장
DO $$
DECLARE
  v_tenant uuid := 'b0000000-0000-0000-0000-000000000001';
  v_user1 uuid := 'a0000000-0000-0000-0000-000000000001'; -- 테스트관리자 (owner)
  v_user2 uuid := 'a0000000-0000-0000-0000-000000000002'; -- 결재자 (member)
  v_user3 uuid := 'a0000000-0000-0000-0000-000000000003'; -- 신규사용자 (member)
  v_form_general uuid;
  v_form_leave uuid;
  v_form_expense uuid;
  v_form_proposal uuid;
  v_form_cooperation uuid;
  v_doc1 uuid := 'f1000000-0000-0000-0000-000000000001';
  v_doc2 uuid := 'f1000000-0000-0000-0000-000000000002';
  v_doc3 uuid := 'f1000000-0000-0000-0000-000000000003';
  v_doc4 uuid := 'f1000000-0000-0000-0000-000000000004';
  v_doc5 uuid := 'f1000000-0000-0000-0000-000000000005';
  v_doc6 uuid := 'f1000000-0000-0000-0000-000000000006';
  v_schema jsonb;
BEGIN
  -- 양식 ID 조회
  SELECT id INTO v_form_general FROM approval_forms WHERE tenant_id = v_tenant AND code = 'general';
  SELECT id INTO v_form_leave FROM approval_forms WHERE tenant_id = v_tenant AND code = 'leave-request';
  SELECT id INTO v_form_expense FROM approval_forms WHERE tenant_id = v_tenant AND code = 'expense-report';
  SELECT id INTO v_form_proposal FROM approval_forms WHERE tenant_id = v_tenant AND code = 'proposal';
  SELECT id INTO v_form_cooperation FROM approval_forms WHERE tenant_id = v_tenant AND code = 'cooperation';

  -- 양식 스키마 스냅샷 (general 기준)
  SELECT schema INTO v_schema FROM approval_forms WHERE id = v_form_general;

  -- 문서번호 시퀀스 초기화
  INSERT INTO doc_number_sequences (tenant_id, day, last_seq)
  VALUES (v_tenant, current_date, 6)
  ON CONFLICT (tenant_id, day) DO UPDATE SET last_seq = GREATEST(doc_number_sequences.last_seq, 6);

  -- ─── DOC1: 완료된 일반 기안서 (전체 승인) ──────────────
  INSERT INTO approval_documents (id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, submitted_at, completed_at, urgency)
  VALUES (v_doc1, v_tenant, 'APP-' || to_char(current_date - 5, 'YYYYMMDD') || '-0001', v_form_general, v_schema,
    '{"title":"사무용품 구매 요청","summary":"모니터 거치대 5개 구매","body":"개발팀에서 사용할 모니터 거치대 5개를 구매 요청합니다."}'::jsonb,
    v_user3, 'completed', 1, now() - interval '5 days', now() - interval '4 days', '일반')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, group_order) VALUES
  (v_tenant, v_doc1, 0, 'approval', v_user2, 'approved', now() - interval '4 days 6 hours', 0),
  (v_tenant, v_doc1, 1, 'approval', v_user1, 'approved', now() - interval '4 days', 1)
  ON CONFLICT (document_id, step_index) DO NOTHING;

  INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload) VALUES
  (v_tenant, v_doc1, v_user3, 'submit', jsonb_build_object('doc_number', 'APP-' || to_char(current_date - 5, 'YYYYMMDD') || '-0001')),
  (v_tenant, v_doc1, v_user2, 'approve', '{"step_index":0}'::jsonb),
  (v_tenant, v_doc1, v_user1, 'approve', '{"step_index":1}'::jsonb);

  -- ─── DOC2: 진행 중 휴가신청서 (1단계 승인, 2단계 대기) ──
  INSERT INTO approval_documents (id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, submitted_at, urgency)
  VALUES (v_doc2, v_tenant, 'APP-' || to_char(current_date - 2, 'YYYYMMDD') || '-0002',
    v_form_leave, (SELECT schema FROM approval_forms WHERE id = v_form_leave),
    '{"leave_type":"annual","period":"2026-04-21 ~ 2026-04-22","reason":"개인 사유로 연차 사용","contact":"010-3456-7890"}'::jsonb,
    v_user3, 'in_progress', 1, now() - interval '2 days', '일반')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, group_order) VALUES
  (v_tenant, v_doc2, 0, 'approval', v_user2, 'approved', now() - interval '1 day', 0),
  (v_tenant, v_doc2, 1, 'approval', v_user1, 'pending', NULL, 1)
  ON CONFLICT (document_id, step_index) DO NOTHING;

  INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload) VALUES
  (v_tenant, v_doc2, v_user3, 'submit', jsonb_build_object('doc_number', 'APP-' || to_char(current_date - 2, 'YYYYMMDD') || '-0002')),
  (v_tenant, v_doc2, v_user2, 'approve', '{"step_index":0}'::jsonb);

  -- ─── DOC3: 반려된 지출결의서 ───────────────────────────
  INSERT INTO approval_documents (id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, submitted_at, urgency)
  VALUES (v_doc3, v_tenant, 'APP-' || to_char(current_date - 3, 'YYYYMMDD') || '-0003',
    v_form_expense, (SELECT schema FROM approval_forms WHERE id = v_form_expense),
    '{"title":"접대비 청구","expense_date":"2026-04-08","amount":350000,"category":"entertainment","description":"거래처 저녁 식사"}'::jsonb,
    v_user2, 'rejected', 0, now() - interval '3 days', '일반')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, acted_at, comment, group_order) VALUES
  (v_tenant, v_doc3, 0, 'approval', v_user1, 'rejected', now() - interval '2 days 18 hours', '영수증이 첨부되지 않았습니다. 재기안 바랍니다.', 0)
  ON CONFLICT (document_id, step_index) DO NOTHING;

  INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload) VALUES
  (v_tenant, v_doc3, v_user2, 'submit', jsonb_build_object('doc_number', 'APP-' || to_char(current_date - 3, 'YYYYMMDD') || '-0003')),
  (v_tenant, v_doc3, v_user1, 'reject', '{"step_index":0,"comment":"영수증이 첨부되지 않았습니다."}'::jsonb);

  -- ─── DOC4: 임시저장 품의서 (미상신) ────────────────────
  INSERT INTO approval_documents (id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, urgency)
  VALUES (v_doc4, v_tenant, 'APP-' || to_char(current_date, 'YYYYMMDD') || '-0004',
    v_form_proposal, (SELECT schema FROM approval_forms WHERE id = v_form_proposal),
    '{"title":"AWS 서버 증설 품의","purpose":"트래픽 증가 대비","budget":5000000,"justification":"월 사용자 300% 증가 예상"}'::jsonb,
    v_user2, 'draft', 0, '일반')
  ON CONFLICT (id) DO NOTHING;

  -- ─── DOC5: 긴급 업무협조전 (진행 중, 합의 포함) ────────
  INSERT INTO approval_documents (id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, submitted_at, urgency)
  VALUES (v_doc5, v_tenant, 'APP-' || to_char(current_date - 1, 'YYYYMMDD') || '-0005',
    v_form_cooperation, (SELECT schema FROM approval_forms WHERE id = v_form_cooperation),
    '{"title":"보안 패치 긴급 적용 요청","target_department":"경영지원팀","deadline":"2026-04-15","content":"CVE-2026-1234 취약점 패치를 긴급 적용해야 합니다."}'::jsonb,
    v_user2, 'in_progress', 0, now() - interval '1 day', '긴급')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, group_order) VALUES
  (v_tenant, v_doc5, 0, 'approval', v_user1, 'pending', 0),
  (v_tenant, v_doc5, 1, 'agreement', v_user3, 'pending', 1)
  ON CONFLICT (document_id, step_index) DO NOTHING;

  INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload) VALUES
  (v_tenant, v_doc5, v_user2, 'submit', jsonb_build_object('doc_number', 'APP-' || to_char(current_date - 1, 'YYYYMMDD') || '-0005'));

  -- ─── DOC6: 회수된 일반 기안서 ──────────────────────────
  INSERT INTO approval_documents (id, tenant_id, doc_number, form_id, form_schema_snapshot, content, drafter_id, status, current_step_index, submitted_at, urgency)
  VALUES (v_doc6, v_tenant, 'APP-' || to_char(current_date - 4, 'YYYYMMDD') || '-0006',
    v_form_general, v_schema,
    '{"title":"출장 보고서 (취소)","summary":"서울 출장 보고","body":"출장이 취소되어 회수합니다."}'::jsonb,
    v_user3, 'withdrawn', 0, now() - interval '4 days', '일반')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO approval_steps (tenant_id, document_id, step_index, step_type, approver_user_id, status, group_order) VALUES
  (v_tenant, v_doc6, 0, 'approval', v_user2, 'skipped', 0)
  ON CONFLICT (document_id, step_index) DO NOTHING;

  INSERT INTO approval_audit_logs (tenant_id, document_id, actor_id, action, payload) VALUES
  (v_tenant, v_doc6, v_user3, 'submit', '{}'::jsonb),
  (v_tenant, v_doc6, v_user3, 'withdraw', '{}'::jsonb);

END;
$$;
