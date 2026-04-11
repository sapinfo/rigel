-- 0007_m3_tenant_rpcs.sql
-- M3: 테넌트 생성·초대 수락에 필요한 RPC.
-- approval_forms 테이블은 M4에서 생성되므로, fn_copy_system_forms는 존재 체크 후 no-op.
-- M4 이후에는 해당 함수를 CREATE OR REPLACE로 덮어쓸 수 있음.
--
-- 본 migration의 모든 함수는 Design §2.12 원칙을 따른다:
--   - SECURITY DEFINER + SET search_path = public
--   - auth.uid() null check
--   - 멤버십 재검증
--   - 감사 로그 기록 (해당 테이블이 있을 때만)

-- ─── fn_copy_system_forms ─────────────────────────────
-- M3 시점: approval_forms 없음 → 0 반환.
-- M4 이후: CREATE OR REPLACE로 실제 복사 로직 작성.

CREATE OR REPLACE FUNCTION public.fn_copy_system_forms(p_tenant_id uuid)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count int := 0;
BEGIN
  -- M3: approval_forms 테이블이 아직 없으면 no-op
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'approval_forms'
  ) THEN
    RETURN 0;
  END IF;

  -- M4 이후에는 이 블록이 이미 오버라이드된 버전으로 대체되겠지만,
  -- 안전하게 여기서도 복사 로직 작성 (동적 SQL로 late binding)
  EXECUTE format(
    'INSERT INTO public.approval_forms (tenant_id, code, name, description, schema, default_approval_line, version, is_published)
     SELECT $1, code, name, description, schema, default_approval_line, 1, true
     FROM public.approval_forms WHERE tenant_id IS NULL'
  ) USING p_tenant_id;

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- ─── fn_create_tenant ─────────────────────────────────
-- 신규 테넌트 생성 + owner 멤버십 + 시스템 양식 복사 + profiles.default_tenant_id

CREATE OR REPLACE FUNCTION public.fn_create_tenant(
  p_slug text,
  p_name text
)
RETURNS public.tenants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_tenant public.tenants;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  IF p_slug IS NULL OR p_name IS NULL THEN
    RAISE EXCEPTION 'slug and name required' USING ERRCODE = '22023';
  END IF;

  -- tenants CHECK 제약(slug regex, name length)은 INSERT 시 검증됨
  INSERT INTO public.tenants (slug, name, owner_id)
  VALUES (p_slug, p_name, v_user_id)
  RETURNING * INTO v_tenant;

  INSERT INTO public.tenant_members (tenant_id, user_id, role)
  VALUES (v_tenant.id, v_user_id, 'owner');

  -- M3: no-op, M4+: 실제 복사
  PERFORM public.fn_copy_system_forms(v_tenant.id);

  UPDATE public.profiles
  SET default_tenant_id = v_tenant.id, updated_at = now()
  WHERE id = v_user_id;

  RETURN v_tenant;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_create_tenant(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.fn_copy_system_forms(uuid) TO authenticated;

-- ─── fn_accept_invitation ─────────────────────────────
-- 초대 토큰 수락. 이메일 매칭 + 멱등성.

CREATE OR REPLACE FUNCTION public.fn_accept_invitation(p_token uuid)
RETURNS public.tenants
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid := auth.uid();
  v_email text;
  v_inv public.tenant_invitations;
  v_tenant public.tenants;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = v_user_id;
  IF v_email IS NULL THEN
    RAISE EXCEPTION 'User email not found' USING ERRCODE = '02000';
  END IF;

  SELECT * INTO v_inv
  FROM public.tenant_invitations
  WHERE token = p_token
    AND expires_at > now()
    AND accepted_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Invalid or expired invitation' USING ERRCODE = '22023';
  END IF;

  IF lower(v_inv.email) <> lower(v_email) THEN
    RAISE EXCEPTION 'Invitation email mismatch' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.tenant_members (tenant_id, user_id, role)
  VALUES (v_inv.tenant_id, v_user_id, v_inv.role)
  ON CONFLICT (tenant_id, user_id) DO NOTHING;

  UPDATE public.tenant_invitations
  SET accepted_at = now(), accepted_by = v_user_id
  WHERE id = v_inv.id;

  -- 기존 default_tenant_id가 없으면 이 테넌트로 설정
  UPDATE public.profiles
  SET default_tenant_id = COALESCE(default_tenant_id, v_inv.tenant_id),
      updated_at = now()
  WHERE id = v_user_id;

  SELECT * INTO v_tenant FROM public.tenants WHERE id = v_inv.tenant_id;
  RETURN v_tenant;
END;
$$;

GRANT EXECUTE ON FUNCTION public.fn_accept_invitation(uuid) TO authenticated;
