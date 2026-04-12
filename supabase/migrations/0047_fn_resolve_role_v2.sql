-- 0047: fn_resolve_role v2 — team_lead/department_head 로직 개선
-- team_lead: 같은 부서에서 기안자보다 바로 위 직급 (ASC LIMIT 1)
-- department_head: 상위 부서에서 최고 직급
-- ceo: 전체 최고 직급 (기존 유지)
-- 중복 결재자 방지: team_lead와 ceo가 같은 사람이면 의미 없음 → 규칙 설계 영역

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
  v_drafter_level int;
  v_parent_dept_id uuid;
BEGIN
  -- 직접 userId 지정 (UUID 형태)
  IF p_role ~ '^[0-9a-f-]{36}$' THEN
    RETURN p_role::uuid;
  END IF;

  IF p_drafter_dept_id IS NULL THEN
    RETURN NULL;
  END IF;

  -- 기안자 직급 레벨 조회
  SELECT COALESCE(jt.level, 0) INTO v_drafter_level
  FROM public.tenant_members tm
  LEFT JOIN public.job_titles jt ON jt.id = tm.job_title_id
  WHERE tm.tenant_id = p_tenant_id AND tm.user_id = p_drafter_id;

  CASE p_role
    WHEN 'team_lead' THEN
      -- 같은 부서에서 기안자보다 바로 위 직급 (level이 가장 낮으면서 기안자보다 높은)
      SELECT tm.user_id INTO v_user_id
      FROM public.tenant_members tm
      JOIN public.job_titles jt ON jt.id = tm.job_title_id
      WHERE tm.tenant_id = p_tenant_id
        AND tm.department_id = p_drafter_dept_id
        AND tm.user_id <> p_drafter_id
        AND jt.level > v_drafter_level
      ORDER BY jt.level ASC
      LIMIT 1;

      -- fallback: 같은 부서에 상위 직급 없으면 상위 부서에서 탐색
      IF v_user_id IS NULL THEN
        SELECT parent_id INTO v_parent_dept_id
        FROM public.departments WHERE id = p_drafter_dept_id;

        IF v_parent_dept_id IS NOT NULL THEN
          SELECT tm.user_id INTO v_user_id
          FROM public.tenant_members tm
          LEFT JOIN public.job_titles jt ON jt.id = tm.job_title_id
          WHERE tm.tenant_id = p_tenant_id
            AND tm.department_id = v_parent_dept_id
            AND tm.user_id <> p_drafter_id
          ORDER BY COALESCE(jt.level, 0) DESC
          LIMIT 1;
        END IF;
      END IF;

      RETURN v_user_id;

    WHEN 'department_head' THEN
      -- 상위 부서에서 최고 직급
      SELECT parent_id INTO v_parent_dept_id
      FROM public.departments WHERE id = p_drafter_dept_id;

      IF v_parent_dept_id IS NOT NULL THEN
        SELECT tm.user_id INTO v_user_id
        FROM public.tenant_members tm
        LEFT JOIN public.job_titles jt ON jt.id = tm.job_title_id
        WHERE tm.tenant_id = p_tenant_id
          AND tm.department_id = v_parent_dept_id
          AND tm.user_id <> p_drafter_id
        ORDER BY COALESCE(jt.level, 0) DESC
        LIMIT 1;
      END IF;

      -- fallback: 상위 부서 없으면 같은 부서 최고 직급
      IF v_user_id IS NULL THEN
        SELECT tm.user_id INTO v_user_id
        FROM public.tenant_members tm
        LEFT JOIN public.job_titles jt ON jt.id = tm.job_title_id
        WHERE tm.tenant_id = p_tenant_id
          AND tm.department_id = p_drafter_dept_id
          AND tm.user_id <> p_drafter_id
          AND COALESCE(jt.level, 0) > v_drafter_level
        ORDER BY jt.level DESC
        LIMIT 1;
      END IF;

      RETURN v_user_id;

    WHEN 'ceo' THEN
      -- 전체 최고 직급 (기안자 제외)
      SELECT tm.user_id INTO v_user_id
      FROM public.tenant_members tm
      JOIN public.job_titles jt ON jt.id = tm.job_title_id
      WHERE tm.tenant_id = p_tenant_id
        AND tm.user_id <> p_drafter_id
        AND jt.level = (
          SELECT MAX(jt2.level) FROM public.job_titles jt2
          WHERE jt2.tenant_id = p_tenant_id
        )
      LIMIT 1;
      RETURN v_user_id;

    ELSE
      RETURN NULL;
  END CASE;
END;
$$;
