CREATE TABLE public.announcement_reads (
  announcement_id uuid NOT NULL REFERENCES public.announcements(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  read_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (announcement_id, user_id)
);

ALTER TABLE public.announcement_reads ENABLE ROW LEVEL SECURITY;

CREATE POLICY announcement_reads_select ON public.announcement_reads
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY announcement_reads_insert ON public.announcement_reads
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND public.is_tenant_member(tenant_id)
  );

CREATE OR REPLACE FUNCTION public.get_unread_announcement_count(p_tenant_id uuid)
  RETURNS integer
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public
AS $$
  SELECT count(*)::integer
  FROM public.announcements a
  WHERE a.tenant_id = p_tenant_id
    AND a.published_at IS NOT NULL
    AND (a.expires_at IS NULL OR a.expires_at > now())
    AND a.require_read_confirm = true
    AND NOT EXISTS (
      SELECT 1 FROM public.announcement_reads ar
      WHERE ar.announcement_id = a.id AND ar.user_id = auth.uid()
    );
$$;

CREATE OR REPLACE FUNCTION public.get_popup_announcements(p_tenant_id uuid)
  RETURNS SETOF public.announcements
  LANGUAGE sql STABLE SECURITY DEFINER
  SET search_path = public
AS $$
  SELECT a.*
  FROM public.announcements a
  WHERE a.tenant_id = p_tenant_id
    AND a.is_popup = true
    AND a.published_at IS NOT NULL
    AND (a.expires_at IS NULL OR a.expires_at > now())
    AND NOT EXISTS (
      SELECT 1 FROM public.announcement_reads ar
      WHERE ar.announcement_id = a.id AND ar.user_id = auth.uid()
    )
  ORDER BY a.published_at DESC;
$$;
