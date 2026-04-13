-- 출퇴근 기록
CREATE TABLE public.attendance_records (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id),
  work_date date NOT NULL,
  clock_in timestamptz,
  clock_out timestamptz,
  work_type text NOT NULL DEFAULT 'normal'
    CHECK (work_type IN ('normal', 'late', 'half_day', 'annual_leave', 'business_trip', 'remote')),
  note text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, user_id, work_date)
);

CREATE INDEX attendance_records_tenant_date ON public.attendance_records
  (tenant_id, work_date DESC);
CREATE INDEX attendance_records_user_date ON public.attendance_records
  (user_id, work_date DESC);

ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;

-- SELECT: 본인 기록 + admin은 전체
CREATE POLICY attendance_records_select ON public.attendance_records
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      user_id = (SELECT auth.uid())
      OR public.is_tenant_admin(tenant_id)
    )
  );

-- INSERT: 본인만
CREATE POLICY attendance_records_insert ON public.attendance_records
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT auth.uid())
    AND public.is_tenant_member(tenant_id)
  );

-- UPDATE: 본인 (clock_out만) OR admin
CREATE POLICY attendance_records_update ON public.attendance_records
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

-- 출근 RPC: idempotent
CREATE OR REPLACE FUNCTION public.fn_clock_in(p_tenant_id uuid)
  RETURNS public.attendance_records
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Seoul')::date;
  v_now timestamptz := now();
  v_settings attendance_settings;
  v_type text := 'normal';
  v_rec attendance_records;
BEGIN
  SELECT * INTO v_settings FROM attendance_settings WHERE tenant_id = p_tenant_id;

  IF v_settings IS NOT NULL THEN
    IF (v_now AT TIME ZONE 'Asia/Seoul')::time >
       (v_settings.work_start_time + (v_settings.late_threshold_minutes || ' minutes')::interval) THEN
      v_type := 'late';
    END IF;
  END IF;

  INSERT INTO attendance_records (tenant_id, user_id, work_date, clock_in, work_type)
  VALUES (p_tenant_id, auth.uid(), v_today, v_now, v_type)
  ON CONFLICT (tenant_id, user_id, work_date) DO NOTHING
  RETURNING * INTO v_rec;

  IF v_rec IS NULL THEN
    SELECT * INTO v_rec FROM attendance_records
    WHERE tenant_id = p_tenant_id AND user_id = auth.uid() AND work_date = v_today;
  END IF;

  RETURN v_rec;
END;
$$;

-- 퇴근 RPC
CREATE OR REPLACE FUNCTION public.fn_clock_out(p_tenant_id uuid)
  RETURNS public.attendance_records
  LANGUAGE plpgsql SECURITY DEFINER
  SET search_path = public
AS $$
DECLARE
  v_today date := (now() AT TIME ZONE 'Asia/Seoul')::date;
  v_rec attendance_records;
BEGIN
  UPDATE attendance_records
  SET clock_out = now()
  WHERE tenant_id = p_tenant_id AND user_id = auth.uid() AND work_date = v_today
  RETURNING * INTO v_rec;

  IF v_rec IS NULL THEN
    RAISE EXCEPTION 'No clock-in record found for today';
  END IF;

  RETURN v_rec;
END;
$$;
