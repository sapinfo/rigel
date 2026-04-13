-- ============================================================
-- Rigel 테스트 seed 데이터
-- supabase start 시 migration 적용 후 자동 실행
-- ============================================================

-- ─── 1. 테스트 계정 (auth.users) ─────────────────────────
-- CLAUDE.md 기준 계정. password = testpass1234
-- confirmation_token 등 모든 token 필드 '' (NULL이면 GoTrue 실패)

INSERT INTO auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at, confirmation_token, recovery_token,
  email_change_token_new, email_change,
  raw_app_meta_data, raw_user_meta_data,
  aud, role, created_at, updated_at
) VALUES
-- m3test1@example.com (owner of m3test-org)
(
  'a0000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000000',
  'm3test1@example.com',
  crypt('testpass1234', gen_salt('bf', 10)),
  now(), '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"테스트관리자"}'::jsonb,
  'authenticated', 'authenticated', now(), now()
),
-- m5approver@example.com (member of m3test-org)
(
  'a0000000-0000-0000-0000-000000000002',
  '00000000-0000-0000-0000-000000000000',
  'm5approver@example.com',
  crypt('testpass1234', gen_salt('bf', 10)),
  now(), '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"결재자"}'::jsonb,
  'authenticated', 'authenticated', now(), now()
),
-- newuser@example.com (member of m3test-org)
(
  'a0000000-0000-0000-0000-000000000003',
  '00000000-0000-0000-0000-000000000000',
  'newuser@example.com',
  crypt('testpass1234', gen_salt('bf', 10)),
  now(), '', '', '', '',
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"display_name":"신규사용자"}'::jsonb,
  'authenticated', 'authenticated', now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- auth.identities (GoTrue 필수)
INSERT INTO auth.identities (
  id, user_id, provider_id, provider, identity_data, last_sign_in_at, created_at, updated_at
) VALUES
(
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000001',
  'm3test1@example.com', 'email',
  '{"sub":"a0000000-0000-0000-0000-000000000001","email":"m3test1@example.com"}'::jsonb,
  now(), now(), now()
),
(
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000002',
  'm5approver@example.com', 'email',
  '{"sub":"a0000000-0000-0000-0000-000000000002","email":"m5approver@example.com"}'::jsonb,
  now(), now(), now()
),
(
  'a0000000-0000-0000-0000-000000000003',
  'a0000000-0000-0000-0000-000000000003',
  'newuser@example.com', 'email',
  '{"sub":"a0000000-0000-0000-0000-000000000003","email":"newuser@example.com"}'::jsonb,
  now(), now(), now()
)
ON CONFLICT (id) DO NOTHING;

-- ─── 2. 테넌트 ──────────────────────────────────────────

INSERT INTO public.tenants (id, slug, name, owner_id)
VALUES (
  'b0000000-0000-0000-0000-000000000001',
  'm3test-org',
  'M3 테스트 조직',
  'a0000000-0000-0000-0000-000000000001'
)
ON CONFLICT (id) DO NOTHING;

-- ─── 3. 멤버십 ──────────────────────────────────────────

INSERT INTO public.tenant_members (tenant_id, user_id, role) VALUES
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'owner'),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'member'),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'member')
ON CONFLICT (tenant_id, user_id) DO NOTHING;

-- ─── 4. profiles default_tenant 설정 ─────────────────────

UPDATE public.profiles
SET default_tenant_id = 'b0000000-0000-0000-0000-000000000001'
WHERE id IN (
  'a0000000-0000-0000-0000-000000000001',
  'a0000000-0000-0000-0000-000000000002',
  'a0000000-0000-0000-0000-000000000003'
);

-- ─── 5. 부서 ─────────────────────────────────────────────

INSERT INTO public.departments (id, tenant_id, name, parent_id, path) VALUES
('d0000000-0000-0000-0000-000000000001', 'b0000000-0000-0000-0000-000000000001', '경영지원팀', NULL, '/경영지원팀'),
('d0000000-0000-0000-0000-000000000002', 'b0000000-0000-0000-0000-000000000001', '개발팀', NULL, '/개발팀'),
('d0000000-0000-0000-0000-000000000003', 'b0000000-0000-0000-0000-000000000001', '영업팀', NULL, '/영업팀')
ON CONFLICT (id) DO NOTHING;

-- user_departments
INSERT INTO public.user_departments (tenant_id, user_id, department_id, is_primary) VALUES
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000001', true),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000002', true),
('b0000000-0000-0000-0000-000000000001', 'a0000000-0000-0000-0000-000000000003', 'd0000000-0000-0000-0000-000000000003', true)
ON CONFLICT (tenant_id, user_id, department_id) DO NOTHING;

-- ─── 6. 시스템 양식 → 테넌트 복사 ─────────────────────────

SELECT public.fn_copy_system_forms('b0000000-0000-0000-0000-000000000001');

-- ─── 7. 근무 설정 (기본값) ────────────────────────────────

INSERT INTO public.attendance_settings (tenant_id)
VALUES ('b0000000-0000-0000-0000-000000000001')
ON CONFLICT (tenant_id) DO NOTHING;
