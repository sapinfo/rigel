-- 0078_realtime_notifications_publication.sql
-- v1.3 M19 핫픽스: notifications 테이블을 supabase_realtime publication에 등록.
-- 0038에서 테이블만 만들고 publication 추가를 누락 → Realtime INSERT 이벤트가
-- 클라이언트로 전달되지 않아 알림 배지·드롭다운이 실시간 갱신 안 됨.
-- RLS (notifications_select_own) 는 그대로 유지 — Realtime 은 RLS 적용된 구독 지원.

BEGIN;

-- 1. publication 에 notifications 테이블 추가 (idempotent)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
     WHERE pubname    = 'supabase_realtime'
       AND schemaname = 'public'
       AND tablename  = 'notifications'
  ) THEN
    EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications';
  END IF;
END $$;

-- 2. REPLICA IDENTITY FULL
-- Realtime 이 RLS 필터 (user_id=eq.<uuid>) 를 평가할 때 이전 행 데이터가 필요.
-- DEFAULT (primary key only) 는 DELETE/UPDATE 시 user_id 접근 불가 → 이벤트 누락.
ALTER TABLE public.notifications REPLICA IDENTITY FULL;

COMMIT;
