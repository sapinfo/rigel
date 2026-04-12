-- 0033_profile_signature.sql
-- v1.2 M15: profiles 에 서명이미지 경로·해시 컬럼 추가.
--
-- Storage 버킷은 0034 에서 별도 생성 (버킷 + 정책 단일 책임).
-- 컬럼 업데이트 권한은 기존 profiles UPDATE 정책(self-only)이 이미 커버.

BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN signature_storage_path text NULL,
  ADD COLUMN signature_sha256 text NULL;

ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_sig_sha_format
    CHECK (signature_sha256 IS NULL OR char_length(signature_sha256) = 64);

COMMENT ON COLUMN public.profiles.signature_storage_path IS
  'v1.2 Storage path in user-signatures bucket: {user_id}/signature.png. NULL = 서명 미등록. 사용자는 /my/profile/signature 에서 업로드.';

COMMENT ON COLUMN public.profiles.signature_sha256 IS
  'v1.2 SHA-256(hex) of signature PNG bytes. 승인 시 audit payload snapshot 에 동일 값 저장 — 프로필 교체 후에도 증거 보존.';

COMMIT;
