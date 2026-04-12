-- 0032_content_hash_columns.sql
-- v1.2 M15: content_hash (approval_documents) + sha256 (approval_attachments) 컬럼 추가.
--
-- NOT NULL 정책:
--   기존 v1.0/v1.1 rows 는 NULL 허용 (backfill 불가 — content_hash 는 JCS canonicalization
--   재현이 원본 시점 정확 재현 어려움).
--   v1.2 이후 신규 상신은 RPC (fn_submit_draft v3, 0035) 에서 content_hash IS NULL 검증 +
--   char_length = 64 + hex pattern 강제.
--
-- CHECK:
--   컬럼 레벨 CHECK 는 length 만 (NULL 허용). NOT NULL 강제는 RPC 에서.

BEGIN;

ALTER TABLE public.approval_documents
  ADD COLUMN content_hash text NULL;

ALTER TABLE public.approval_documents
  ADD CONSTRAINT ad_content_hash_format
    CHECK (content_hash IS NULL OR char_length(content_hash) = 64);

COMMENT ON COLUMN public.approval_documents.content_hash IS
  'v1.2 SHA-256(hex) of JCS-canonicalized {form_schema, content, approval_line, attachment_sha256s}. NULL for pre-v1.2 docs. v1.2+ submissions: NOT NULL enforced by RPC (fn_submit_draft v3).';

ALTER TABLE public.approval_attachments
  ADD COLUMN sha256 text NULL;

ALTER TABLE public.approval_attachments
  ADD CONSTRAINT aa_sha256_format
    CHECK (sha256 IS NULL OR char_length(sha256) = 64);

COMMENT ON COLUMN public.approval_attachments.sha256 IS
  'v1.2 SHA-256(hex) of attachment file bytes. Computed client-side via crypto.subtle.digest. NULL for pre-v1.2 rows. Enforced NOT NULL at submit time via fn_submit_draft v3 validation.';

COMMIT;
