-- 0044_approval_rules.sql
-- v2.0 M29: 결재선 자동 구성 규칙 테이블 + fn_resolve_approval_line + helpers
-- Design: §3 Migration 0044

BEGIN;

-- ─── 1. approval_rules 테이블 ───────────────────────────────
CREATE TABLE public.approval_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
  form_id uuid REFERENCES public.approval_forms(id) ON DELETE CASCADE,
  name text NOT NULL,
  condition_json jsonb,
  line_template_json jsonb NOT NULL,
  priority int NOT NULL DEFAULT 100,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ar_tenant_idx ON public.approval_rules (tenant_id);
CREATE INDEX ar_form_idx ON public.approval_rules (form_id) WHERE form_id IS NOT NULL;
CREATE INDEX ar_priority_idx ON public.approval_rules (tenant_id, priority, is_active);

ALTER TABLE public.approval_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY ar_member_select ON public.approval_rules
  FOR SELECT TO authenticated
  USING (public.is_tenant_member(tenant_id));

CREATE POLICY ar_admin_insert ON public.approval_rules
  FOR INSERT TO authenticated
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY ar_admin_update ON public.approval_rules
  FOR UPDATE TO authenticated
  USING (public.is_tenant_admin(tenant_id))
  WITH CHECK (public.is_tenant_admin(tenant_id));

CREATE POLICY ar_admin_delete ON public.approval_rules
  FOR DELETE TO authenticated
  USING (public.is_tenant_admin(tenant_id));

-- ─── 2. fn_eval_condition (조건 평가 헬퍼) ──────────────────
CREATE OR REPLACE FUNCTION public.fn_eval_condition(
  p_cond jsonb,
  p_val text
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_op text := p_cond->>'operator';
  v_target text := p_cond->>'value';
BEGIN
  IF p_val IS NULL THEN RETURN false; END IF;
  RETURN CASE v_op
    WHEN 'eq'       THEN p_val = v_target
    WHEN 'neq'      THEN p_val <> v_target
    WHEN 'gte'      THEN p_val::numeric >= v_target::numeric
    WHEN 'lte'      THEN p_val::numeric <= v_target::numeric
    WHEN 'contains' THEN p_val ILIKE '%' || v_target || '%'
    ELSE false
  END;
EXCEPTION WHEN OTHERS THEN
  RETURN false;
END;
$$;

-- ─── 3. fn_resolve_role (role → user_id) ────────────────────
CREATE OR REPLACE FUNCTION public.fn_resolve_role(
  p_tenant_id uuid,
  p_drafter_id uuid,
  p_drafter_dept_id uuid,
  p_role text
)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_parent_dept_id uuid;
  v_depth int := 0;
  v_target_depth int;
BEGIN
  -- 직접 userId 지정 (UUID 형태)
  IF p_role ~ '^[0-9a-f-]{36}$' THEN
    RETURN p_role::uuid;
  END IF;

  IF p_drafter_dept_id IS NULL THEN
    RETURN NULL;
  END IF;

  CASE p_role
    WHEN 'team_lead' THEN v_target_depth := 1;
    WHEN 'department_head' THEN v_target_depth := 2;
    WHEN 'ceo' THEN
      -- 최상위 부서의 멤버 중 level 최고 직급 사용자
      SELECT tm.user_id INTO v_user_id
      FROM public.tenant_members tm
      JOIN public.job_titles jt ON jt.id = tm.job_title_id
      WHERE tm.tenant_id = p_tenant_id
        AND jt.level = (
          SELECT MAX(jt2.level) FROM public.job_titles jt2
          WHERE jt2.tenant_id = p_tenant_id
        )
      LIMIT 1;
      RETURN v_user_id;
    ELSE
      RETURN NULL;
  END CASE;

  -- 조직도 상위 탐색 (depth 단계만큼)
  v_parent_dept_id := p_drafter_dept_id;
  WHILE v_depth < v_target_depth LOOP
    SELECT parent_id INTO v_parent_dept_id
    FROM public.departments
    WHERE id = v_parent_dept_id;

    IF v_parent_dept_id IS NULL THEN
      EXIT;  -- 더 이상 상위 없음
    END IF;
    v_depth := v_depth + 1;
  END LOOP;

  IF v_parent_dept_id IS NULL THEN
    v_parent_dept_id := p_drafter_dept_id;  -- fallback: 현재 부서
  END IF;

  -- 해당 부서의 멤버 중 직급 level이 가장 높은 사용자 (본인 제외)
  SELECT tm.user_id INTO v_user_id
  FROM public.tenant_members tm
  LEFT JOIN public.job_titles jt ON jt.id = tm.job_title_id
  WHERE tm.tenant_id = p_tenant_id
    AND tm.department_id = v_parent_dept_id
    AND tm.user_id <> p_drafter_id
  ORDER BY COALESCE(jt.level, 0) DESC
  LIMIT 1;

  RETURN v_user_id;
END;
$$;

-- ─── 4. fn_resolve_approval_line ────────────────────────────
CREATE OR REPLACE FUNCTION public.fn_resolve_approval_line(
  p_tenant_id uuid,
  p_form_id uuid,
  p_content jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_rule record;
  v_cond jsonb;
  v_field_val text;
  v_cond_matched boolean;
  v_step jsonb;
  v_role text;
  v_step_cond jsonb;
  v_approver_user_id uuid;
  v_result jsonb := '[]'::jsonb;
  v_drafter_dept_id uuid;
BEGIN
  -- 기안자 부서 조회
  SELECT department_id INTO v_drafter_dept_id
  FROM public.tenant_members
  WHERE tenant_id = p_tenant_id AND user_id = v_user_id;

  -- 매칭 규칙 탐색
  SELECT * INTO v_rule
  FROM public.approval_rules
  WHERE tenant_id = p_tenant_id
    AND is_active = true
    AND (form_id = p_form_id OR form_id IS NULL)
  ORDER BY
    (form_id IS NULL) ASC,
    priority ASC
  LIMIT 1;

  IF v_rule.id IS NULL THEN
    RETURN '[]'::jsonb;
  END IF;

  -- condition_json 평가
  v_cond := v_rule.condition_json;
  IF v_cond IS NOT NULL THEN
    v_field_val := p_content ->> (v_cond->>'field');
    v_cond_matched := public.fn_eval_condition(v_cond, v_field_val);
    IF NOT v_cond_matched THEN
      RETURN '[]'::jsonb;
    END IF;
  END IF;

  -- line_template_json → ApprovalLineItem[] 변환
  FOR v_step IN SELECT * FROM jsonb_array_elements(v_rule.line_template_json) LOOP
    v_role := v_step->>'role';

    -- 개별 step 조건 평가
    v_step_cond := v_step->'condition';
    IF v_step_cond IS NOT NULL AND v_step_cond <> 'null'::jsonb THEN
      v_field_val := p_content ->> (v_step_cond->>'field');
      IF NOT public.fn_eval_condition(v_step_cond, v_field_val) THEN
        CONTINUE;
      END IF;
    END IF;

    v_approver_user_id := public.fn_resolve_role(
      p_tenant_id, v_user_id, v_drafter_dept_id, v_role
    );

    IF v_approver_user_id IS NULL THEN
      CONTINUE;
    END IF;

    v_result := v_result || jsonb_build_object(
      'userId', v_approver_user_id,
      'stepType', COALESCE(v_step->>'stepType', 'approval')
    );
  END LOOP;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_resolve_approval_line(uuid, uuid, jsonb) TO authenticated;

COMMIT;
