import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { type Handle, redirect } from '@sveltejs/kit';
import { sequence } from '@sveltejs/kit/hooks';
import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';

/**
 * Inject Supabase server client into event.locals.
 * Uses @supabase/ssr with the `getAll`/`setAll` cookie pattern.
 */
const supabase: Handle = async ({ event, resolve }) => {
  event.locals.supabase = createServerClient(
    PUBLIC_SUPABASE_URL,
    PUBLIC_SUPABASE_ANON_KEY,
    {
      cookies: {
        getAll: () => event.cookies.getAll(),
        setAll: (cookiesToSet: { name: string; value: string; options: CookieOptions }[]) => {
          cookiesToSet.forEach(({ name, value, options }) => {
            event.cookies.set(name, value, { ...options, path: '/' });
          });
        }
      }
    }
  );

  /**
   * `safeGetSession` verifies the session cookie by round-tripping to
   * Supabase Auth with `getUser()`. Never trust `getSession()` alone.
   */
  event.locals.safeGetSession = async () => {
    const {
      data: { session }
    } = await event.locals.supabase.auth.getSession();
    if (!session) return { session: null, user: null };

    const {
      data: { user },
      error
    } = await event.locals.supabase.auth.getUser();
    if (error) return { session: null, user: null };

    return { session, user };
  };

  return resolve(event, {
    filterSerializedResponseHeaders: (name) =>
      name === 'content-range' || name === 'x-supabase-api-version'
  });
};

/**
 * Public routes: no authentication required.
 * Everything else redirects to /login when not authenticated.
 * Tenant-level authorization is handled in t/[tenantSlug]/+layout.server.ts.
 */
const PUBLIC_ROUTES = ['/', '/login', '/signup', '/invite'];

function isPublicRoute(pathname: string): boolean {
  return PUBLIC_ROUTES.some(
    (p) => pathname === p || pathname.startsWith(p + '/')
  );
}

/**
 * Populate locals.session / locals.user from the verified session and
 * enforce route-level auth. Tenant context (locals.currentTenant) is set
 * downstream by t/[tenantSlug]/+layout.server.ts.
 */
const authGuard: Handle = async ({ event, resolve }) => {
  const { session, user } = await event.locals.safeGetSession();
  event.locals.session = session;
  event.locals.user = user;
  event.locals.currentTenant = null;

  const path = event.url.pathname;
  const isPublic = isPublicRoute(path);

  // Unauthenticated access to protected routes → redirect to /login
  if (!isPublic && !user) {
    const redirectTo = path + (event.url.search ?? '');
    redirect(303, `/login?redirect=${encodeURIComponent(redirectTo)}`);
  }

  // Authenticated access to /login or /signup → redirect to home
  if (user && (path === '/login' || path === '/signup')) {
    redirect(303, '/');
  }

  return resolve(event);
};

export const handle: Handle = sequence(supabase, authGuard);
