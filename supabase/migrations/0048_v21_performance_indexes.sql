-- 0048: v2.1 성능 인덱스 — tenant_members department/job_title 조회 최적화
CREATE INDEX IF NOT EXISTS tm_department_idx
  ON public.tenant_members (department_id)
  WHERE department_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS tm_job_title_idx
  ON public.tenant_members (job_title_id)
  WHERE job_title_id IS NOT NULL;
