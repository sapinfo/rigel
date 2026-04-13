CREATE TABLE public.employee_profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  employee_number text,
  hire_date date,
  phone_office text,
  phone_mobile text,
  job_title text,
  job_position text,
  bio text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX employee_profiles_tenant_idx ON public.employee_profiles (tenant_id);

ALTER TABLE public.employee_profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY employee_profiles_select ON public.employee_profiles
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY employee_profiles_insert ON public.employee_profiles
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

CREATE POLICY employee_profiles_update ON public.employee_profiles
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );
