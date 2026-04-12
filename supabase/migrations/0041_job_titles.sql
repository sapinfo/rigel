-- 0041_job_titles.sql
-- v2.0 M25: 직급 테이블 + departments FOR ALL 정책을 per-action으로 교체
-- Design: §3 Migration 0041

BEGIN;

-- ─── 1. job_titles 테이블 ───────────────────────────────────
CREATE TABLE public.job_titles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  name text NOT NULL,
  level int NOT NULL CHECK (level BETWEEN 1 AND 10),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, name)
);

CREATE INDEX job_titles_tenant_idx ON public.job_titles (tenant_id);

ALTER TABLE public.job_titles ENABLE ROW LEVEL SECURITY;

CREATE POLICY jt_member_select ON public.job_titles
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY jt_admin_insert ON public.job_titles
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY jt_admin_update ON public.job_titles
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY jt_admin_delete ON public.job_titles
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));

-- departments per-action 정책은 0006에서 이미 교체 완료. 스킵.

COMMIT;
