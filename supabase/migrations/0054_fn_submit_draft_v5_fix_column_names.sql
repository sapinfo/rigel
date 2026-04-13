-- 0054: fn_submit_draft v5 — delegation_rules 컬럼명 수정
-- delegator_id → delegator_user_id
-- effective_until → effective_to
-- is_active 조건 제거 (컬럼 없음)
-- 기존 0045 fn_submit_draft_v4의 delegation 쿼리 버그 수정

-- 전체 함수는 Supabase MCP로 직접 적용 완료.
-- 이 파일은 migration 이력 기록용.
