-- 0037_approver_group_idx.sql
-- v1.2 Gap G1: inbox 병렬 그룹 쿼리 성능 개선 인덱스.
-- Design §3.4 에서 명시된 partial index.

CREATE INDEX IF NOT EXISTS as_approver_group_idx
  ON public.approval_steps (approver_user_id, group_order)
  WHERE status = 'pending';
