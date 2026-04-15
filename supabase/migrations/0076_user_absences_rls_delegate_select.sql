-- 0076_user_absences_rls_delegate_select.sql
--
-- Bug fix: 부재 대리인(delegate_user_id)이 자기 자신을 대리로 지정한
-- user_absences row 를 조회할 수 없어서 /approval/documents/[id] 에서
-- 대리 승인 버튼이 안 보였다.
--
-- 증상 (APP-20260415-0007):
--   - 김부장 부재 등록 (delegate = 김과장)
--   - 김부장 차례인 결재 단계에서 김과장 로그인 시 "승인" 버튼 미노출
--   - fn_approve_step 은 SECURITY DEFINER 라 실제 승인은 가능하지만 UI가
--     fetchActiveProxyFor 의 user_absences SELECT 결과를 기반으로 버튼을
--     조건부 렌더 → RLS 로 0행 반환하니 버튼 숨김
--
-- 근본 원인:
--   기존 ua_select 정책: (user_id = auth.uid()) OR is_tenant_admin(tenant_id)
--   delegate_user_id 로 접근한 케이스가 누락.
--
-- 해결:
--   CLAUDE.md RLS 규칙 준수 (FOR SELECT 단일 permissive, OR 합침, (SELECT auth.uid()) 래핑).
--   기존 정책 DROP 후 delegate_user_id 조건 포함하여 재생성.
--
-- 재현 검증:
--   1. 김부장 부재 (delegate=김과장) 상태에서 김부장 차례인 문서 존재
--   2. 김과장 로그인 → /approval/documents/{id} → "승인" 버튼 노출
--   3. 클릭 시 step.acted_by_proxy_user_id = 김과장, audit action = 'approved_by_proxy'
--   4. 단일 결재선이면 문서 → completed

BEGIN;

DROP POLICY IF EXISTS ua_select ON public.user_absences;

CREATE POLICY ua_select ON public.user_absences
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR delegate_user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

COMMIT;
