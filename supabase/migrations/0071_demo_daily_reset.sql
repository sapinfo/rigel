-- 데모 환경 일일 데이터 리셋
-- pg_cron으로 매일 자정(KST) = UTC 15:00에 실행
-- seed_create_document() 헬퍼(0070)에 의존

CREATE OR REPLACE FUNCTION public.fn_reset_demo_data()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tenant uuid := 'b0000000-0000-0000-0000-000000000001';
  v_user1 uuid := 'a0000000-0000-0000-0000-000000000001';
  v_user2 uuid := 'a0000000-0000-0000-0000-000000000002';
  v_user3 uuid := 'a0000000-0000-0000-0000-000000000003';
BEGIN
  -- ─── 1. 사용자 생성 데이터 삭제 (FK CASCADE로 연쇄) ─────
  -- 결재 관련
  TRUNCATE approval_audit_logs CASCADE;
  TRUNCATE approval_steps CASCADE;
  TRUNCATE approval_documents CASCADE;
  TRUNCATE approval_attachments CASCADE;
  TRUNCATE notifications CASCADE;
  TRUNCATE doc_number_sequences CASCADE;
  TRUNCATE approval_line_favorites CASCADE;
  TRUNCATE approval_line_templates CASCADE;
  TRUNCATE approval_rules CASCADE;
  TRUNCATE delegation_rules CASCADE;
  TRUNCATE user_absences CASCADE;

  -- 그룹웨어
  TRUNCATE board_comments CASCADE;
  TRUNCATE board_posts CASCADE;
  TRUNCATE boards CASCADE;
  TRUNCATE board_attachments CASCADE;
  TRUNCATE announcement_reads CASCADE;
  TRUNCATE announcements CASCADE;
  TRUNCATE room_reservations CASCADE;
  TRUNCATE meeting_rooms CASCADE;
  TRUNCATE calendar_events CASCADE;
  TRUNCATE attendance_records CASCADE;
  TRUNCATE employee_profiles CASCADE;

  -- ─── 2. 시드 데이터 재생성 ─────────────────────────────

  -- 게시판
  INSERT INTO boards (id, tenant_id, name, description, board_type, department_id, sort_order, created_by) VALUES
  ('c1000000-0000-0000-0000-000000000001', v_tenant, '자유게시판', '자유롭게 소통하는 공간', 'general', NULL, 1, v_user1),
  ('c1000000-0000-0000-0000-000000000002', v_tenant, '사내 공유', '업무 관련 정보 공유', 'general', NULL, 2, v_user1),
  ('c1000000-0000-0000-0000-000000000003', v_tenant, '개발팀 게시판', '개발팀 내부 소통', 'department', 'd0000000-0000-0000-0000-000000000002', 3, v_user1);

  -- 게시글
  INSERT INTO board_posts (id, board_id, tenant_id, title, content, author_id, is_pinned, view_count) VALUES
  ('c2000000-0000-0000-0000-000000000001', 'c1000000-0000-0000-0000-000000000001', v_tenant, '4월 회식 장소 추천 받습니다',
   '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"이번 달 회식 장소 추천해주세요!"}]}]}'::jsonb, v_user3, false, 12),
  ('c2000000-0000-0000-0000-000000000002', 'c1000000-0000-0000-0000-000000000001', v_tenant, '사내 동호회 모집 (풋살)',
   '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"풋살 동호회를 만들려고 합니다."}]}]}'::jsonb, v_user2, false, 8),
  ('c2000000-0000-0000-0000-000000000003', 'c1000000-0000-0000-0000-000000000002', v_tenant, '[필독] 2026년 연차 사용 가이드',
   '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"상반기 내 50% 이상 소진 권장합니다."}]}]}'::jsonb, v_user1, true, 45),
  ('c2000000-0000-0000-0000-000000000004', 'c1000000-0000-0000-0000-000000000002', v_tenant, '신규 업무 프로세스 안내',
   '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"4월부터 결재 프로세스가 변경됩니다."}]}]}'::jsonb, v_user1, false, 23),
  ('c2000000-0000-0000-0000-000000000005', 'c1000000-0000-0000-0000-000000000003', v_tenant, 'Sprint 14 회고',
   '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"이번 스프린트 회고 정리합니다."}]}]}'::jsonb, v_user2, false, 5);

  -- 댓글
  INSERT INTO board_comments (id, post_id, tenant_id, author_id, content) VALUES
  ('c3000000-0000-0000-0000-000000000001', 'c2000000-0000-0000-0000-000000000001', v_tenant, v_user2, '역삼동 고기집 어떨까요?'),
  ('c3000000-0000-0000-0000-000000000002', 'c2000000-0000-0000-0000-000000000001', v_tenant, v_user1, '좋습니다! 예약해주세요.'),
  ('c3000000-0000-0000-0000-000000000003', 'c2000000-0000-0000-0000-000000000002', v_tenant, v_user3, '저도 참여하고 싶습니다!');

  -- 공지
  INSERT INTO announcements (id, tenant_id, title, content, author_id, is_popup, require_read_confirm, published_at, expires_at) VALUES
  ('c4000000-0000-0000-0000-000000000001', v_tenant, '개인정보 보호 교육 안내 (필수 이수)',
   '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"전 직원 대상 개인정보 보호 교육을 이수해주세요."}]}]}'::jsonb,
   v_user1, true, true, now() - interval '2 days', now() + interval '30 days'),
  ('c4000000-0000-0000-0000-000000000002', v_tenant, '4월 급여 지급일 안내',
   '{"type":"doc","content":[{"type":"paragraph","content":[{"type":"text","text":"4월 급여는 4월 25일(금)에 지급됩니다."}]}]}'::jsonb,
   v_user1, false, false, now() - interval '1 day', NULL);

  -- 회의실
  INSERT INTO meeting_rooms (id, tenant_id, name, location, capacity) VALUES
  ('c5000000-0000-0000-0000-000000000001', v_tenant, '대회의실', '3층 301호', 20),
  ('c5000000-0000-0000-0000-000000000002', v_tenant, '소회의실 A', '2층 205호', 6),
  ('c5000000-0000-0000-0000-000000000003', v_tenant, '소회의실 B', '2층 206호', 4);

  -- 회의실 예약
  INSERT INTO room_reservations (room_id, tenant_id, title, reserved_by, start_at, end_at) VALUES
  ('c5000000-0000-0000-0000-000000000001', v_tenant, '주간 전체 회의', v_user1,
   (current_date + 1)::date + time '10:00', (current_date + 1)::date + time '11:00'),
  ('c5000000-0000-0000-0000-000000000002', v_tenant, '개발팀 스프린트 플래닝', v_user2,
   (current_date + 1)::date + time '14:00', (current_date + 1)::date + time '15:30');

  -- 일정
  INSERT INTO calendar_events (tenant_id, title, start_at, end_at, all_day, event_type, department_id, created_by, color) VALUES
  (v_tenant, '상반기 워크숍', (current_date + 7)::date + time '09:00', (current_date + 7)::date + time '18:00', false, 'company', NULL, v_user1, '#3b82f6'),
  (v_tenant, '개발팀 코드리뷰 데이', (current_date + 2)::date + time '14:00', (current_date + 2)::date + time '17:00', false, 'department', 'd0000000-0000-0000-0000-000000000002', v_user2, '#10b981'),
  (v_tenant, '창립기념일', (current_date + 14)::date, (current_date + 14)::date + time '23:59', true, 'company', NULL, v_user1, '#ef4444');

  -- 인사 프로필
  INSERT INTO employee_profiles (user_id, tenant_id, employee_number, hire_date, phone_mobile, job_title, job_position) VALUES
  (v_user1, v_tenant, 'EMP-001', '2020-03-02', '010-1234-5678', '팀장', '부장'),
  (v_user2, v_tenant, 'EMP-002', '2022-07-15', '010-2345-6789', NULL, '과장'),
  (v_user3, v_tenant, 'EMP-003', '2025-01-06', '010-3456-7890', NULL, '사원');

  -- 출퇴근 (최근 3일)
  INSERT INTO attendance_records (tenant_id, user_id, work_date, clock_in, clock_out, work_type) VALUES
  (v_tenant, v_user1, current_date - 2, (current_date - 2)::date + time '08:55', (current_date - 2)::date + time '18:10', 'normal'),
  (v_tenant, v_user1, current_date - 1, (current_date - 1)::date + time '09:25', (current_date - 1)::date + time '19:00', 'late'),
  (v_tenant, v_user2, current_date - 1, (current_date - 1)::date + time '09:00', (current_date - 1)::date + time '18:00', 'normal');

  -- ─── 3. 결재 문서 (헬퍼 사용) ──────────────────────────

  PERFORM seed_create_document(v_tenant, 'general', v_user3,
    '사무용품 구매 요청', '{"title":"사무용품 구매 요청","summary":"모니터 거치대 5개"}'::jsonb,
    ARRAY[v_user2, v_user1], 'completed', '일반', NULL, NULL, NULL, 5);

  PERFORM seed_create_document(v_tenant, 'leave-request', v_user3,
    '연차 사용', '{"leave_type":"annual","reason":"개인 사유"}'::jsonb,
    ARRAY[v_user2, v_user1], 'in_progress', '일반', NULL, NULL, NULL, 2);

  PERFORM seed_create_document(v_tenant, 'expense-report', v_user2,
    '접대비 청구', '{"title":"접대비 청구","amount":350000}'::jsonb,
    ARRAY[v_user1], 'rejected', '일반', 0, '영수증 미첨부', NULL, 3);

  PERFORM seed_create_document(v_tenant, 'proposal', v_user2,
    'AWS 서버 증설 품의', '{"title":"AWS 서버 증설","budget":5000000}'::jsonb,
    ARRAY[]::uuid[], 'draft', '일반', NULL, NULL, NULL, 0);

  PERFORM seed_create_document(v_tenant, 'cooperation', v_user2,
    '보안 패치 긴급 적용', '{"title":"보안 패치 긴급 적용"}'::jsonb,
    ARRAY[v_user1, v_user3], 'in_progress', '긴급', NULL, NULL, ARRAY['approval','agreement'], 1);

  PERFORM seed_create_document(v_tenant, 'general', v_user3,
    '출장 보고서 (취소)', '{"title":"출장 보고서 (취소)"}'::jsonb,
    ARRAY[v_user2], 'withdrawn', '일반', NULL, NULL, NULL, 4);

  RAISE NOTICE 'Demo data reset completed at %', now();
END;
$$;

-- pg_cron: 매일 자정 KST (= UTC 15:00) 실행
-- CLAUDE.md 규칙: unschedule 후 재등록 (idempotent)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'demo_daily_reset') THEN
    PERFORM cron.unschedule('demo_daily_reset');
  END IF;
END $$;

SELECT cron.schedule(
  'demo_daily_reset',
  '0 15 * * *',  -- UTC 15:00 = KST 00:00
  $$SELECT public.fn_reset_demo_data()$$
);
