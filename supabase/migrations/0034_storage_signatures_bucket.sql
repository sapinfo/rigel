-- 0034_storage_signatures_bucket.sql
-- v1.2 M15: user-signatures Storage 버킷 + RLS 정책 4종 (insert/update/select/delete).
--
-- 경로 규칙: {user_id}/signature.png
-- 버킷 공개 여부: private (public=false), 접근은 signed URL 또는 RLS-aware API 로만.
-- 정책:
--   sig_insert_self    — 본인 prefix 만 업로드
--   sig_update_self    — 본인 prefix 만 교체 (USING + WITH CHECK 양쪽)
--   sig_read_tenant_mates — 같은 tenant 멤버 read (승인 step 옆 서명 렌더용)
--   sig_delete_self    — 본인만 삭제
--
-- FOR ALL 금지 규칙 준수 — action 별 정책 분리.
-- storage.foldername(name)[1] 결과가 첫 path segment (= user_id) 임을 확인 완료.

BEGIN;

INSERT INTO storage.buckets (id, name, public)
VALUES ('user-signatures', 'user-signatures', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "sig_insert_self"
  ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'user-signatures'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

CREATE POLICY "sig_update_self"
  ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'user-signatures'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  )
  WITH CHECK (
    bucket_id = 'user-signatures'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

CREATE POLICY "sig_read_tenant_mates"
  ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'user-signatures'
    AND EXISTS (
      SELECT 1
      FROM public.tenant_members m_self
      JOIN public.tenant_members m_other ON m_self.tenant_id = m_other.tenant_id
      WHERE m_self.user_id = (SELECT auth.uid())
        AND m_other.user_id::text = (storage.foldername(name))[1]
    )
  );

CREATE POLICY "sig_delete_self"
  ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'user-signatures'
    AND (storage.foldername(name))[1] = (SELECT auth.uid())::text
  );

COMMIT;
