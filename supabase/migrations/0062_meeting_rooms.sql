CREATE TABLE public.meeting_rooms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  location text,
  capacity integer,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.meeting_rooms ENABLE ROW LEVEL SECURITY;

CREATE POLICY meeting_rooms_select ON public.meeting_rooms
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY meeting_rooms_insert ON public.meeting_rooms
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY meeting_rooms_update ON public.meeting_rooms
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id));

CREATE POLICY meeting_rooms_delete ON public.meeting_rooms
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));
