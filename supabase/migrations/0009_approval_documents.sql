-- 0009_approval_documents.sql
-- 결재 문서. ad_select 정책은 approval_steps 참조가 필요하므로 0010에서 추가.
-- 모든 INSERT/UPDATE는 RPC 경유. 직접 INSERT 차단.

CREATE TYPE public.document_status AS ENUM (
  'draft',
  'in_progress',
  'completed',
  'rejected',
  'withdrawn'
);

CREATE TABLE public.approval_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  doc_number text NOT NULL,
  form_id uuid NOT NULL REFERENCES public.approval_forms(id) ON DELETE RESTRICT,
  form_schema_snapshot jsonb NOT NULL,
  content jsonb NOT NULL DEFAULT '{}'::jsonb,
  drafter_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  status public.document_status NOT NULL DEFAULT 'draft',
  current_step_index int NOT NULL DEFAULT 0,
  submitted_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, doc_number)
);

CREATE INDEX ad_tenant_idx ON public.approval_documents (tenant_id);
CREATE INDEX ad_drafter_idx ON public.approval_documents (tenant_id, drafter_id);
CREATE INDEX ad_status_idx ON public.approval_documents (tenant_id, status);
CREATE INDEX ad_form_idx ON public.approval_documents (form_id);

ALTER TABLE public.approval_documents ENABLE ROW LEVEL SECURITY;

-- UPDATE: 기안자 본인의 draft만 수정 가능 (임시저장 중)
CREATE POLICY ad_drafter_draft_update ON public.approval_documents
  FOR UPDATE TO authenticated
  USING (
    drafter_id = (SELECT auth.uid())
    AND status = 'draft'
    AND public.is_tenant_member(tenant_id)
  )
  WITH CHECK (
    drafter_id = (SELECT auth.uid())
    AND public.is_tenant_member(tenant_id)
  );

-- INSERT: 직접 INSERT 차단. fn_submit_draft / fn_save_draft RPC 경유
CREATE POLICY ad_no_direct_insert ON public.approval_documents
  FOR INSERT TO authenticated
  WITH CHECK (false);

-- NOTE: ad_select 정책은 approval_steps에 대한 EXISTS를 포함하므로 0010 migration에서 추가한다
