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
