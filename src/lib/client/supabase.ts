import { createBrowserClient } from '@supabase/ssr';
import { env } from '$env/dynamic/public';
import { debugFetch } from './debug';

/**
 * 프로젝트 공통 브라우저 supabase 클라이언트 팩토리.
 *
 * cookieOptions.name 을 'sb-rigel-auth-token' 으로 고정하여
 * hooks.server.ts의 server client와 세션 쿠키를 공유.
 *
 * 기본 쿠키 이름은 URL 첫 서브도메인 기반(예: sb-api-auth-token)이라
 * 서버(kong:8000)와 클라이언트(api.rigelworks.io) 사이 이름이 어긋남.
 *
 * global.fetch로 debugFetch 주입 — 모든 supabase-js 호출 실패 시
 * 자동으로 브라우저 콘솔에 에러 기록. localStorage에 최근 200건 롤링 저장.
 */
export function createRigelBrowserClient() {
  return createBrowserClient(
    env.PUBLIC_SUPABASE_URL!,
    env.PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookieOptions: { name: 'sb-rigel-auth-token' },
      global: { fetch: debugFetch }
    }
  );
}
