-- 0040_pg_cron_notification_cleanup.sql
-- v1.3 M19: 90일 이상 read=true 알림 자동 삭제 (pg_cron)
-- Design: §4, R26
-- 주의: pg_cron은 TX 외부에서 실행 (ALTER TYPE ... ADD VALUE 규칙과 동일)

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'cleanup_old_notifications') THEN
    PERFORM cron.unschedule('cleanup_old_notifications');
  END IF;
END $$;

-- UTC 18:00 = KST 03:00 (다음날)
SELECT cron.schedule(
  'cleanup_old_notifications',
  '0 18 * * *',
  $cmd$
    DELETE FROM public.notifications
    WHERE read = true
      AND created_at < now() - interval '90 days';
  $cmd$
);
