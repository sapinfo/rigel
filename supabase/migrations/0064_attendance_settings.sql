-- 근무 시간 설정 (fn_clock_in이 참조하므로 attendance_records보다 선행)
CREATE TABLE public.attendance_settings (
  tenant_id uuid PRIMARY KEY REFERENCES public.tenants(id) ON DELETE CASCADE,
  work_start_time time NOT NULL DEFAULT '09:00',
  work_end_time time NOT NULL DEFAULT '18:00',
  late_threshold_minutes integer NOT NULL DEFAULT 10,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.attendance_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY attendance_settings_select ON public.attendance_settings
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY attendance_settings_insert ON public.attendance_settings
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY attendance_settings_update ON public.attendance_settings
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id));
