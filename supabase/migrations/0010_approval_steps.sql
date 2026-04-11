-- 0010_approval_steps.sql
-- 결재선 스냅샷. 상신 시점에 INSERT되어 이후 인사발령과 독립.
-- 이 migration에서 approval_documents의 ad_select 정책을 추가한다 (approval_steps 참조 포함).

CREATE TYPE public.step_type AS ENUM ('approval', 'reference');
CREATE TYPE public.step_status AS ENUM ('pending', 'approved', 'rejected', 'skipped');

CREATE TABLE public.approval_steps (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES public.approval_documents(id) ON DELETE CASCADE,
  step_index int NOT NULL,
  step_type public.step_type NOT NULL,
  approver_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  status public.step_status NOT NULL DEFAULT 'pending',
  acted_at timestamptz,
  comment text,
  UNIQUE (document_id, step_index)
);

CREATE INDEX as_tenant_idx ON public.approval_steps (tenant_id);
CREATE INDEX as_document_idx ON public.approval_steps (document_id);
CREATE INDEX as_approver_pending_idx
  ON public.approval_steps (tenant_id, approver_user_id)
  WHERE status = 'pending';

ALTER TABLE public.approval_steps ENABLE ROW LEVEL SECURITY;

-- ─── approval_documents.ad_select (지연 추가) ────────
-- 0009에서 approval_steps 미존재로 추가 못했던 정책. 이제 추가.

CREATE POLICY ad_select ON public.approval_documents
  FOR SELECT TO authenticated
  USING (
    public.is_tenant_member(tenant_id)
    AND (
      drafter_id = (SELECT auth.uid())
      OR public.is_tenant_admin(tenant_id)
      OR EXISTS (
        SELECT 1 FROM public.approval_steps s
        WHERE s.document_id = public.approval_documents.id
          AND s.approver_user_id = (SELECT auth.uid())
      )
    )
  );

-- ─── approval_steps RLS ──────────────────────────────

-- SELECT: 부모 문서가 읽기 가능하면 step도 읽기 가능
-- (subquery로 document RLS 재사용 — 사용자는 한 번만 평가됨)
CREATE POLICY as_select ON public.approval_steps
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.approval_documents d
      WHERE d.id = public.approval_steps.document_id
        AND public.is_tenant_member(d.tenant_id)
        AND (
          d.drafter_id = (SELECT auth.uid())
          OR public.is_tenant_admin(d.tenant_id)
          OR public.approval_steps.approver_user_id = (SELECT auth.uid())
        )
    )
  );

-- INSERT: 직접 차단. fn_submit_draft RPC 경유
CREATE POLICY as_no_direct_insert ON public.approval_steps
  FOR INSERT TO authenticated
  WITH CHECK (false);

-- UPDATE: 본인 단계(pending) 중에만 본인이 수정 가능 (단, 실제로는 fn_approve_step/fn_reject_step이 수행)
CREATE POLICY as_self_pending_update ON public.approval_steps
  FOR UPDATE TO authenticated
  USING (
    approver_user_id = (SELECT auth.uid())
    AND status = 'pending'
    AND public.is_tenant_member(tenant_id)
  )
  WITH CHECK (
    approver_user_id = (SELECT auth.uid())
    AND public.is_tenant_member(tenant_id)
  );
