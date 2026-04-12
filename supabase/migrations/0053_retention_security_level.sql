-- 0053: 보관기한 + 보안등급 메타데이터 (v2.3 M4)
ALTER TABLE public.approval_documents
  ADD COLUMN IF NOT EXISTS retention_period text NOT NULL DEFAULT '5년';

ALTER TABLE public.approval_documents
  ADD COLUMN IF NOT EXISTS security_level text NOT NULL DEFAULT '일반';

COMMENT ON COLUMN public.approval_documents.retention_period IS '1년 | 3년 | 5년 | 10년 | 영구';
COMMENT ON COLUMN public.approval_documents.security_level IS '일반 | 대외비 | 비밀';
