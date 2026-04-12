-- 0030_pg_cron_absence_backup.sql
-- v1.1 M14: Rigel 첫 pg_cron 도입.
--
-- 매일 KST 00:00 (UTC 15:00 전날) — 모든 활성 absence에 대해
-- fn_auto_delegate_on_absence를 호출. 멱등성으로 trigger 누락분만 복구.
--
-- 설치:
--   - pg_cron extension 활성화 (Supabase local + cloud 모두 지원)
--   - cron job 'absence-auto-delegate-daily-backup' 등록
--
-- 시간대 주의:
--   - pg_cron은 UTC 기준
--   - KST 00:00 = UTC 15:00 (전날)
--   - cron expression: '0 15 * * *'
--
-- 멱등성:
--   - 동일 이름 cron job이 이미 등록돼 있으면 unschedule 후 재등록 (idempotent migration)
--   - fn_auto_delegate_on_absence 자체도 멱등 (이미 재배정된 행 자연 제외)

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 동일 이름 job이 있으면 제거 (재실행 안전)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'absence-auto-delegate-daily-backup'
  ) THEN
    PERFORM cron.unschedule('absence-auto-delegate-daily-backup');
  END IF;
END $$;

-- 매일 KST 00:00 (UTC 15:00) — 활성 absence 전체 백업 재배정
SELECT cron.schedule(
  'absence-auto-delegate-daily-backup',
  '0 15 * * *',
  $cmd$
    SELECT public.fn_auto_delegate_on_absence(id)
      FROM public.user_absences
     WHERE now() BETWEEN start_at AND end_at
  $cmd$
);
