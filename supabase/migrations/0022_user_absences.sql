-- 0022_user_absences.sql
-- v1.1 M12: 대결(Proxy) — 사용자 부재 테이블.
--
-- 개요:
--   - 부재 등록 시 해당 사용자의 결재는 대리인이 수행 가능 (fn_approve_step 내부 체크)
--   - 본인이 스스로 등록 (self-service) 하거나 관리자가 대신 등록 가능
--   - scope_form_id: NULL = 전 결재 대리, UUID = 해당 양식만 대리
--
-- RLS:
--   - SELECT: 본인 OR tenant admin
--   - INSERT/UPDATE/DELETE: 본인 OR tenant admin
--   - (SELECT auth.uid()) 래핑 준수
--
-- 참고: M14에서 trigger 추가 예정 (부재 등록 시 즉시 재배정)
--       v1.1 첫 구현에서는 trigger 없이 fn_approve_step의 실시간 proxy 체크로 동작.

CREATE TYPE public.absence_type AS ENUM ('annual', 'sick', 'business_trip', 'other');

CREATE TABLE public.user_absences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  delegate_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  absence_type public.absence_type NOT NULL DEFAULT 'other',
  scope_form_id uuid NULL REFERENCES public.approval_forms(id) ON DELETE CASCADE,
  start_at timestamptz NOT NULL,
  end_at   timestamptz NOT NULL,
  reason text NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_absences_self_check CHECK (user_id <> delegate_user_id),
  CONSTRAINT user_absences_range_check CHECK (end_at > start_at)
);

CREATE INDEX ua_active_idx
  ON public.user_absences (tenant_id, user_id, start_at, end_at);

CREATE INDEX ua_delegate_idx
  ON public.user_absences (tenant_id, delegate_user_id);

COMMENT ON TABLE public.user_absences IS
  'v1.1 User absence records. Used for proxy approval (fn_approve_step) and future auto-delegation.';

ALTER TABLE public.user_absences ENABLE ROW LEVEL SECURITY;

-- SELECT: 본인 OR tenant admin (전체 멤버 노출은 v1.2 검토)
CREATE POLICY ua_select ON public.user_absences
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

-- INSERT: 본인 OR admin
CREATE POLICY ua_insert ON public.user_absences
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      user_id = (SELECT auth.uid())
      AND public.is_tenant_member(tenant_id)
    )
    OR public.is_tenant_admin(tenant_id)
  );

-- UPDATE: 본인 OR admin
CREATE POLICY ua_update ON public.user_absences
  FOR UPDATE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  )
  WITH CHECK (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );

-- DELETE: 본인 OR admin
CREATE POLICY ua_delete ON public.user_absences
  FOR DELETE TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.is_tenant_admin(tenant_id)
  );
