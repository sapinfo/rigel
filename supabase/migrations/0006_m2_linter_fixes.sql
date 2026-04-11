-- 0006_m2_linter_fixes.sql
-- Supabase advisor WARN fixes for M2:
--   (1) auth_rls_initplan: wrap auth.uid() in (SELECT ...) for per-query caching
--   (2) multiple_permissive_policies: drop redundant self_select, split FOR ALL
--
-- See: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select
-- See: https://supabase.com/docs/guides/database/database-linter

-- ─── profiles ────────────────────────────────────────
-- profiles_self_select is strictly a subset of profiles_tenant_peer_select
-- (peer already allows id = auth.uid()), so drop self_select to avoid
-- multiple_permissive_policies on SELECT.

DROP POLICY profiles_self_select ON public.profiles;
DROP POLICY profiles_self_update ON public.profiles;
DROP POLICY profiles_tenant_peer_select ON public.profiles;

CREATE POLICY profiles_select ON public.profiles
  FOR SELECT TO authenticated
  USING (
    id = (SELECT auth.uid())
    OR EXISTS (
      SELECT 1 FROM public.tenant_members m1
      JOIN public.tenant_members m2 ON m1.tenant_id = m2.tenant_id
      WHERE m1.user_id = (SELECT auth.uid())
        AND m2.user_id = public.profiles.id
    )
  );

CREATE POLICY profiles_self_update ON public.profiles
  FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()));

-- ─── departments ─────────────────────────────────────
-- Replace FOR ALL with per-action policies to avoid overlap on SELECT.

DROP POLICY dept_admin_write ON public.departments;

CREATE POLICY dept_admin_insert ON public.departments
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY dept_admin_update ON public.departments
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY dept_admin_delete ON public.departments
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));

-- ─── user_departments ────────────────────────────────

DROP POLICY ud_admin_write ON public.user_departments;

CREATE POLICY ud_admin_insert ON public.user_departments
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY ud_admin_update ON public.user_departments
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY ud_admin_delete ON public.user_departments
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));
