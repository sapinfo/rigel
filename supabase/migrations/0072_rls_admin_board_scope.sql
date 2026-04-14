-- ─── 0072: RLS boards_select에 admin scope 추가 ─────────────
--
-- 기존 정책: 부서 타입 게시판은 해당 부서 소속 사용자만 조회 가능
-- 문제: owner/admin이 본인 부서 배정이 없으면 모든 부서 게시판을 볼 수 없음 (관리 불가)
-- 해결: `is_tenant_admin(tenant_id) OR ...` 절 추가
--
-- 참조: docs/archive/2026-04/프로덕션-docker-배포/analysis.md §3 O2
--
-- ⚠ announcements_select는 이미 is_tenant_admin 반영됨 (0059).
-- ⚠ meeting_rooms / room_reservations는 is_tenant_member 전체 공개라 수정 불필요.
-- ⚠ calendar_events.personal은 프라이버시상 admin에게도 비공개 유지 (수정 안 함).

DROP POLICY IF EXISTS boards_select ON public.boards;

CREATE POLICY boards_select ON public.boards
  FOR SELECT
  USING (
    is_tenant_member(tenant_id) AND (
      is_tenant_admin(tenant_id)
      OR board_type = 'general'
      OR department_id IN (
        SELECT ud.department_id
        FROM user_departments ud
        WHERE ud.user_id = (SELECT auth.uid())
          AND ud.tenant_id = boards.tenant_id
      )
    )
  );
