-- 0002_tenants.sql
-- 테넌트(조직). 공유 스키마 멀티 테넌트의 루트 테이블.

CREATE TABLE public.tenants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text UNIQUE NOT NULL CHECK (
    slug ~ '^[a-z0-9][a-z0-9-]{1,30}[a-z0-9]$'
  ),
  name text NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
  plan text NOT NULL DEFAULT 'free' CHECK (plan IN ('free', 'pro', 'enterprise')),
  owner_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  settings jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX tenants_owner_idx ON public.tenants (owner_id);

-- profiles.default_tenant_id FK (0001의 placeholder 보정)
ALTER TABLE public.profiles
  ADD CONSTRAINT profiles_default_tenant_fk
  FOREIGN KEY (default_tenant_id) REFERENCES public.tenants(id) ON DELETE SET NULL;

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;

-- tenants.select 정책은 0003 tenant_members + is_tenant_member() 정의 후 추가
