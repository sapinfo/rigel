-- 0012_approval_audit_logs.sql
-- 감사 로그. append-only. UPDATE/DELETE 정책 없음 → 기본 거부.
-- 모든 mutation RPC가 내부에서 자동으로 기록한다.

CREATE TYPE public.audit_action AS ENUM (
  'draft_saved',
  'submit',
  'approve',
  'reject',
  'withdraw',
  'comment'
);

CREATE TABLE public.approval_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  document_id uuid NOT NULL REFERENCES public.approval_documents(id) ON DELETE CASCADE,
  actor_id uuid NOT NULL REFERENCES auth.users(id),
  action public.audit_action NOT NULL,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX aal_document_idx ON public.approval_audit_logs (document_id, created_at);
CREATE INDEX aal_tenant_idx ON public.approval_audit_logs (tenant_id);
CREATE INDEX aal_actor_idx ON public.approval_audit_logs (actor_id);

ALTER TABLE public.approval_audit_logs ENABLE ROW LEVEL SECURITY;

-- SELECT: 문서 읽기 가능하면 감사 로그도 읽기 가능
CREATE POLICY aal_select ON public.approval_audit_logs
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.approval_documents d
      WHERE d.id = public.approval_audit_logs.document_id
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
  );

-- INSERT: 직접 차단. RPC에서만 기록
CREATE POLICY aal_no_direct_insert ON public.approval_audit_logs
  FOR INSERT TO authenticated
  WITH CHECK (false);

-- UPDATE/DELETE 정책 없음 = 기본 거부 (append-only)
