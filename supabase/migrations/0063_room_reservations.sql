CREATE TABLE public.room_reservations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id uuid NOT NULL REFERENCES public.meeting_rooms(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  reserved_by uuid NOT NULL REFERENCES auth.users(id),
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_at > start_at),
  EXCLUDE USING gist (
    room_id WITH =,
    tstzrange(start_at, end_at) WITH &&
  )
);

CREATE INDEX room_reservations_room_range ON public.room_reservations
  (room_id, start_at, end_at);

ALTER TABLE public.room_reservations ENABLE ROW LEVEL SECURITY;

CREATE POLICY room_reservations_select ON public.room_reservations
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY room_reservations_insert ON public.room_reservations
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_tenant_member(tenant_id)
    AND reserved_by = (SELECT auth.uid())
  );

CREATE POLICY room_reservations_update ON public.room_reservations
  FOR UPDATE TO authenticated
  USING (
    reserved_by = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

CREATE POLICY room_reservations_delete ON public.room_reservations
  FOR DELETE TO authenticated
  USING (
    reserved_by = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );
