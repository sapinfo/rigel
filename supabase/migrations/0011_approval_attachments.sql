-- 0011_approval_attachments.sql
-- 첨부파일 메타데이터 + Storage 버킷 + Storage RLS.
-- Storage 경로 규칙: {tenant_id}/{YYYY-MM}/{upload_uuid}.{ext}
-- document_id IS NULL = pending (상신 전), 값 세팅 = 확정.

CREATE TABLE public.approval_attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  document_id uuid REFERENCES public.approval_documents(id) ON DELETE CASCADE,
  storage_path text NOT NULL,
  file_name text NOT NULL,            -- 원본 파일명 (다운로드 시 복원용)
  mime text NOT NULL,
  size bigint NOT NULL CHECK (size >= 0 AND size <= 52428800),  -- 50MB
  uploaded_by uuid NOT NULL REFERENCES auth.users(id),
  uploaded_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX att_tenant_idx ON public.approval_attachments (tenant_id);
CREATE INDEX att_document_idx ON public.approval_attachments (document_id);
CREATE INDEX att_uploaded_by_idx ON public.approval_attachments (uploaded_by);

ALTER TABLE public.approval_attachments ENABLE ROW LEVEL SECURITY;

-- ─── approval_attachments RLS ────────────────────────

-- SELECT: 업로드자 본인 OR 문서 읽기 가능한 사용자
CREATE POLICY att_select ON public.approval_attachments
  FOR SELECT TO authenticated
  USING (
    uploaded_by = (SELECT auth.uid())
    OR (
      document_id IS NOT NULL
      AND EXISTS (
        SELECT 1 FROM public.approval_documents d
        WHERE d.id = public.approval_attachments.document_id
          AND public.is_tenant_member(d.tenant_id)
          AND (
            d.drafter_id = (SELECT auth.uid())
            OR public.is_tenant_admin(d.tenant_id)
            OR EXISTS (
              SELECT 1 FROM public.approval_steps s
              WHERE s.document_id = d.id
                AND s.approver_user_id = (SELECT auth.uid())
            )
          )
      )
    )
  );

-- INSERT: 업로드자 본인 + 멤버 + pending 상태(document_id IS NULL)
CREATE POLICY att_own_insert ON public.approval_attachments
  FOR INSERT TO authenticated
  WITH CHECK (
    uploaded_by = (SELECT auth.uid())
    AND public.is_tenant_member(tenant_id)
    AND document_id IS NULL
  );

-- DELETE: 업로드자 본인 + pending 상태
CREATE POLICY att_own_delete ON public.approval_attachments
  FOR DELETE TO authenticated
  USING (
    uploaded_by = (SELECT auth.uid())
    AND document_id IS NULL
  );

-- UPDATE: document_id를 NULL → value로 승격하는 작업은 fn_submit_draft RPC에서
-- 직접 UPDATE 정책은 없음 (암묵적 거부)

-- ─── Storage bucket + RLS ───────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('approval-attachments', 'approval-attachments', false)
ON CONFLICT DO NOTHING;

-- Storage 경로의 첫 세그먼트(tenant_id)로 테넌트 멤버십 검증
-- (storage.foldername 은 path를 '/'로 split한 array)

CREATE POLICY att_storage_select ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'approval-attachments'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT tenant_id FROM public.tenant_members WHERE user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY att_storage_insert ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'approval-attachments'
    AND (storage.foldername(name))[1]::uuid IN (
      SELECT tenant_id FROM public.tenant_members WHERE user_id = (SELECT auth.uid())
    )
  );

CREATE POLICY att_storage_delete ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'approval-attachments'
    AND owner = (SELECT auth.uid())
  );
