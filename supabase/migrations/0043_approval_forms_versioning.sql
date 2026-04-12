-- 0043_approval_forms_versioning.sql
-- v2.0 M27: parent_form_id 추가 + v_latest_forms 뷰.
-- Design: §3 Migration 0043

BEGIN;

ALTER TABLE public.approval_forms
  ADD COLUMN IF NOT EXISTS parent_form_id uuid
    REFERENCES public.approval_forms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS af_parent_idx
  ON public.approval_forms (parent_form_id)
  WHERE parent_form_id IS NOT NULL;

-- 각 form 계보의 최신 버전만 조회하는 뷰
CREATE OR REPLACE VIEW public.v_latest_forms AS
SELECT DISTINCT ON (COALESCE(parent_form_id, id))
  id,
  tenant_id,
  code,
  name,
  description,
  schema,
  version,
  parent_form_id,
  is_published,
  created_at,
  updated_at
FROM public.approval_forms
WHERE tenant_id IS NOT NULL
ORDER BY COALESCE(parent_form_id, id), version DESC;

COMMIT;
