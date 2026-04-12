-- 0039_pg_net_edge_function.sql
-- v1.3 M19: pg_net extension + Edge Function URL 설정 + fn_notify_email_async 실체화
-- Design: §5.2

BEGIN;

-- ─── 1. pg_net extension ────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS pg_net;

-- ─── 2. app_settings 테이블 (Edge Function URL 저장) ────────
CREATE TABLE IF NOT EXISTS public.app_settings (
  key   text PRIMARY KEY,
  value text NOT NULL
);

COMMENT ON TABLE public.app_settings IS
  'v1.3: 애플리케이션 환경 설정 (Edge Function URL 등).';

INSERT INTO public.app_settings (key, value)
  VALUES ('edge_function_base_url', 'http://host.docker.internal:54321/functions/v1')
  ON CONFLICT (key) DO NOTHING;

-- ─── 3. fn_notify_email_async 실제 구현 (stub 교체) ─────────
CREATE OR REPLACE FUNCTION public.fn_notify_email_async(
  p_document_id uuid,
  p_tenant_id   uuid,
  p_action      text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base_url text;
  v_url      text;
  v_payload  jsonb;
BEGIN
  SELECT value INTO v_base_url
    FROM public.app_settings
   WHERE key = 'edge_function_base_url';

  IF v_base_url IS NULL THEN
    RETURN;
  END IF;

  v_url := v_base_url || '/send-notification-email';

  v_payload := jsonb_build_object(
    'document_id', p_document_id,
    'tenant_id',   p_tenant_id,
    'action',      p_action
  );

  PERFORM net.http_post(
    url     := v_url,
    body    := v_payload::text,
    headers := '{"Content-Type": "application/json"}'::jsonb
  );
EXCEPTION WHEN OTHERS THEN
  RAISE WARNING 'fn_notify_email_async error: %', SQLERRM;
END;
$$;

COMMIT;
