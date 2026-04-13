-- Supabase Auth (GoTrue) requires these roles
-- supabase/postgres image may create them, but ensure they exist

DO $$
BEGIN
  -- Auth admin role
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'supabase_auth_admin') THEN
    CREATE ROLE supabase_auth_admin LOGIN CREATEROLE CREATEDB REPLICATION BYPASSRLS;
  END IF;

  -- Set password to match POSTGRES_PASSWORD
  EXECUTE format('ALTER ROLE supabase_auth_admin WITH PASSWORD %L', current_setting('app.postgres_password', true));

  -- Anon and authenticated roles for PostgREST
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'anon') THEN
    CREATE ROLE anon NOLOGIN NOINHERIT;
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'authenticated') THEN
    CREATE ROLE authenticated NOLOGIN NOINHERIT;
  END IF;

  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'service_role') THEN
    CREATE ROLE service_role NOLOGIN NOINHERIT BYPASSRLS;
  END IF;

  -- Grant permissions
  GRANT anon TO authenticator;
  GRANT authenticated TO authenticator;
  GRANT service_role TO authenticator;

EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'Role setup: %', SQLERRM;
END;
$$;

-- Auth schema
CREATE SCHEMA IF NOT EXISTS auth AUTHORIZATION supabase_auth_admin;
