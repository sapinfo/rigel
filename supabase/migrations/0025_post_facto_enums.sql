-- 0025_post_facto_enums.sql
-- v1.1 M13: 후결(Post-facto) 지원을 위한 enum 확장.
--
-- document_status += 'pending_post_facto': 사후결재 진행 중 상태.
--   fn_submit_post_facto에서 새 문서를 이 상태로 생성.
--   fn_approve_step/reject/withdraw는 0026에서 이 상태도 수용하도록 확장.
--   최종 승인 완료 시 'completed'로 전환 (v1.0과 동일).
--
-- audit_action += 'submitted_post_facto': 후결 상신 감사 로그.
--
-- NOTE: PG 12+ 에서 ALTER TYPE ADD VALUE는 같은 TX에서 해당 값을 사용 불가.
-- 본 파일은 단독 실행되므로 안전.

ALTER TYPE public.document_status ADD VALUE IF NOT EXISTS 'pending_post_facto';
ALTER TYPE public.audit_action ADD VALUE IF NOT EXISTS 'submitted_post_facto';
