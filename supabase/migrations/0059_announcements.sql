CREATE TABLE public.announcements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  content jsonb NOT NULL DEFAULT '{}',
  author_id uuid NOT NULL REFERENCES auth.users(id),
  is_popup boolean NOT NULL DEFAULT false,
  require_read_confirm boolean NOT NULL DEFAULT false,
  published_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX announcements_tenant_idx ON public.announcements (tenant_id, published_at DESC);

ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;

CREATE POLICY announcements_select ON public.announcements
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      published_at IS NOT NULL
      OR public.is_tenant_admin(tenant_id)
    )
  );

CREATE POLICY announcements_insert ON public.announcements
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY announcements_update ON public.announcements
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id));

CREATE POLICY announcements_delete ON public.announcements
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));
