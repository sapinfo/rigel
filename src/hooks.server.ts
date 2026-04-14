import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { type Handle, redirect } from '@sveltejs/kit';
import { sequence } from '@sveltejs/kit/hooks';
import { env } from '$env/dynamic/public';
import { env as privateEnv } from '$env/dynamic/private';
import { warmUpPdfRenderer } from '$lib/server/pdf/renderDocument';

// v1.2 M17: puppeteer Chromium warm-up at boot time.
// R19 mitigation: Vitest / SSR build 는 global.process.env 로 가드.
// Vitest 는 VITEST env 를 자동 설정하며, SvelteKit 의 SSR build 단계에서는
// 이 파일이 실행되지 않음 (서버 런타임에서만 import 됨). 따라서 이 top-level 호출은
// 실제 서버 프로세스 시작 시 1회만 실행됨.
if (!process.env.VITEST && process.env.NODE_ENV !== 'test') {
  // fire-and-forget — 실패해도 첫 요청 시 재시도
  void warmUpPdfRenderer();
}

/**
 * Inject Supabase server client into event.locals.
 * Uses @supabase/ssr with the `getAll`/`setAll` cookie pattern.
 */
const supabase: Handle = async ({ event, resolve }) => {
  // Server uses internal Docker URL (kong:8000), browser uses public URL (localhost:8000)
  const serverUrl = privateEnv.SUPABASE_INTERNAL_URL || env.PUBLIC_SUPABASE_URL!;
  // HTTP 배포(예: LAN)에서는 secure 쿠키가 브라우저에서 드롭됨.
  // SvelteKit은 production에서 secure=true가 기본이므로 프로토콜로 명시 오버라이드.
  const isSecure = event.url.protocol === 'https:';

  event.locals.supabase = createServerClient(
    serverUrl,
    env.PUBLIC_SUPABASE_ANON_KEY!,
    {
      // cookieOptions.name 명시 → 서버/클라이언트가 같은 쿠키 이름 사용.
      // 기본값은 URL의 첫 서브도메인으로 naming됨 (예: http://kong:8000 → sb-kong-auth-token).
      // 서버는 SUPABASE_INTERNAL_URL=http://kong:8000, 클라이언트는 PUBLIC_SUPABASE_URL=https://api.x 로
      // URL이 달라지면 쿠키 이름 미스매치 → 클라이언트가 세션 못 읽음.
      cookieOptions: {
        name: 'sb-rigel-auth-token'
      },
      cookies: {
        getAll: () => event.cookies.getAll(),
        setAll: (cookiesToSet: { name: string; value: string; options: CookieOptions }[]) => {
          cookiesToSet.forEach(({ name, value, options }) => {
            // httpOnly=false: 브라우저 createBrowserClient가 세션을 읽어 Authorization 헤더를
            //   자동 첨부할 수 있게 허용. 없으면 realtime/RPC 호출이 anonymous로 나가고
            //   auth.uid()=null이 되어 알림/구독 등 client-side 기능 전부 실패.
            // secure/sameSite는 XSS·CSRF 1차 방어 유지.
            event.cookies.set(name, value, {
              ...options,
              path: '/',
              secure: isSecure,
              httpOnly: false
            });
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
