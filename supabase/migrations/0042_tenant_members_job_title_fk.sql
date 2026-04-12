-- 0042_tenant_members_job_title_fk.sql
-- v2.0 M25: tenant_members에 job_title_id FK 추가.
-- 기존 job_title text 컬럼은 하위 호환을 위해 유지.

ALTER TABLE public.tenant_members
  ADD COLUMN IF NOT EXISTS job_title_id uuid
    REFERENCES public.job_titles(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS tm_job_title_idx
  ON public.tenant_members (job_title_id);
