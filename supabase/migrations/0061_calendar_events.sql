CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE public.calendar_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  start_at timestamptz NOT NULL,
  end_at timestamptz NOT NULL,
  all_day boolean NOT NULL DEFAULT false,
  event_type text NOT NULL DEFAULT 'personal'
    CHECK (event_type IN ('personal', 'department', 'company')),
  department_id uuid REFERENCES public.departments(id) ON DELETE SET NULL,
  created_by uuid NOT NULL REFERENCES auth.users(id),
  color text,
  recurrence_rule text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (end_at >= start_at)
);

CREATE INDEX calendar_events_tenant_range ON public.calendar_events
  (tenant_id, start_at, end_at);

ALTER TABLE public.calendar_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY calendar_events_select ON public.calendar_events
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      event_type = 'company'
      OR (event_type = 'personal' AND created_by = (SELECT auth.uid()))
      OR (event_type = 'department' AND department_id IN (
        SELECT ud.department_id FROM public.user_departments ud
        WHERE ud.user_id = (SELECT auth.uid()) AND ud.tenant_id = calendar_events.tenant_id
      ))
    )
  );

CREATE POLICY calendar_events_insert ON public.calendar_events
  FOR INSERT TO authenticated
  WITH CHECK (
    public.is_tenant_member(tenant_id)
    AND created_by = (SELECT auth.uid())
    AND (
      event_type = 'personal'
      OR (event_type = 'department' AND public.is_tenant_admin(tenant_id))
      OR (event_type = 'company' AND public.is_tenant_admin(tenant_id))
    )
  );

CREATE POLICY calendar_events_update ON public.calendar_events
  FOR UPDATE TO authenticated
  USING (
    created_by = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

CREATE POLICY calendar_events_delete ON public.calendar_events
  FOR DELETE TO authenticated
  USING (
    created_by = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );
