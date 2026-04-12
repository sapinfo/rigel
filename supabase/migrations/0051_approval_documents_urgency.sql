-- 0051: 긴급 문서 (v2.2 M7)
ALTER TABLE public.approval_documents
  ADD COLUMN IF NOT EXISTS urgency text NOT NULL DEFAULT '일반';

COMMENT ON COLUMN public.approval_documents.urgency IS '일반 | 긴급';
