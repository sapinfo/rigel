/**
 * 안정화 단계용 클라이언트 디버그 유틸.
 *
 * - window.onerror / unhandledrejection 전역 캐처
 * - supabase-js fetch 래퍼 (non-2xx 응답 + 네트워크 실패 로깅)
 * - localStorage 롤링 버퍼 (최근 200개)
 * - `?debug=1` 또는 `localStorage.rigel_debug=true` 시 verbose 모드
 *
 * 민감정보 미기록: JWT, apikey 헤더, body 본문은 기록 X.
 * 기록 대상: timestamp, URL pathname, method, status, error message, tenant slug (if in URL).
 */

import { browser } from '$app/environment';

type DebugEvent = {
  ts: string;
  kind: 'error' | 'unhandled' | 'api-fail' | 'console';
  message: string;
  detail?: Record<string, unknown>;
};

const STORAGE_KEY = 'rigel_debug_events';
const MAX_EVENTS = 200;

/** 활성화 여부 (URL ?debug=1 또는 localStorage rigel_debug) */
export function isDebugMode(): boolean {
  if (!browser) return false;
  try {
    const url = new URL(window.location.href);
    if (url.searchParams.get('debug') === '1') return true;
    return window.localStorage.getItem('rigel_debug') === 'true';
  } catch {
    return false;
  }
}

/** 이벤트 1건 기록 */
function record(ev: DebugEvent): void {
  if (!browser) return;
  // 콘솔은 항상 (verbose 여부 무관)
  const tag = `[rigel:${ev.kind}]`;
  if (ev.kind === 'unhandled' || ev.kind === 'error' || ev.kind === 'api-fail') {
    // eslint-disable-next-line no-console
    console.warn(tag, ev.message, ev.detail ?? '');
  } else if (isDebugMode()) {
    // eslint-disable-next-line no-console
    console.log(tag, ev.message, ev.detail ?? '');
  }

  // 롤링 버퍼
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    const buf: DebugEvent[] = raw ? (JSON.parse(raw) as DebugEvent[]) : [];
    buf.push(ev);
    if (buf.length > MAX_EVENTS) buf.splice(0, buf.length - MAX_EVENTS);
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(buf));
  } catch {
    // localStorage 실패 무시 (쿼터/시크릿모드)
  }
}

/** 최근 이벤트 가져오기 (향후 Debug 오버레이 B단계에서 사용) */
export function getRecentEvents(): DebugEvent[] {
  if (!browser) return [];
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    return raw ? (JSON.parse(raw) as DebugEvent[]) : [];
  } catch {
    return [];
  }
}

export function clearDebugEvents(): void {
  if (!browser) return;
  try {
    window.localStorage.removeItem(STORAGE_KEY);
  } catch {
    // ignore
  }
}

/** 전역 에러 핸들러 설치 (onMount에서 1회 호출) */
let installed = false;
export function installGlobalErrorHandlers(): void {
  if (!browser || installed) return;
  installed = true;

  window.addEventListener('error', (ev) => {
    record({
      ts: new Date().toISOString(),
      kind: 'error',
      message: ev.message || 'Uncaught error',
      detail: {
        filename: ev.filename,
        line: ev.lineno,
        col: ev.colno,
        stack: ev.error?.stack?.split('\n').slice(0, 5).join('\n')
      }
    });
  });

  window.addEventListener('unhandledrejection', (ev) => {
    const reason = ev.reason;
    const message =
      reason instanceof Error ? reason.message : typeof reason === 'string' ? reason : 'Promise rejection';
    record({
      ts: new Date().toISOString(),
      kind: 'unhandled',
      message,
      detail: {
        stack: reason instanceof Error ? reason.stack?.split('\n').slice(0, 5).join('\n') : undefined,
        reasonType: typeof reason
      }
    });
  });

  // 부트 로그
  record({
    ts: new Date().toISOString(),
    kind: 'console',
    message: 'debug handlers installed',
    detail: { url: window.location.href }
  });
}

/**
 * fetch 래퍼 — supabase-js의 `global.fetch` 로 주입.
 * Supabase PostgREST/Auth/Storage 호출 실패 시 자동 로그.
 */
export function debugFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const method = init?.method ?? 'GET';
  const url = typeof input === 'string' ? input : input instanceof URL ? input.href : input.url;

  const start = performance.now();
  return fetch(input, init)
    .then((res) => {
      if (!res.ok) {
        // 응답은 한 번만 읽을 수 있으므로 clone().
        // body 본문은 민감할 수 있으니 size/status만 기본 기록.
        const ms = Math.round(performance.now() - start);
        res
          .clone()
          .text()
          .then((text) => {
            // Supabase 에러는 JSON — code/message만 추출 (token 류 제거)
            let summary = text.slice(0, 300);
            try {
              const parsed = JSON.parse(text);
              if (parsed && typeof parsed === 'object') {
                summary = JSON.stringify({
                  code: (parsed as { code?: unknown }).code,
                  message: (parsed as { message?: unknown }).message,
                  hint: (parsed as { hint?: unknown }).hint
                });
              }
            } catch {
              // plain text — keep snippet
            }
            record({
              ts: new Date().toISOString(),
              kind: 'api-fail',
              message: `${method} ${safePath(url)} → ${res.status}`,
              detail: { status: res.status, ms, body: summary }
            });
          })
          .catch(() => {
            record({
              ts: new Date().toISOString(),
              kind: 'api-fail',
              message: `${method} ${safePath(url)} → ${res.status}`,
              detail: { status: res.status, ms }
            });
          });
      }
      return res;
    })
    .catch((err: Error) => {
      const ms = Math.round(performance.now() - start);
      record({
        ts: new Date().toISOString(),
        kind: 'api-fail',
        message: `${method} ${safePath(url)} → NETWORK_ERROR`,
        detail: { error: err.message, ms }
      });
      throw err;
    });
}

/** URL에서 host + path만 뽑아서 민감 query는 버림 */
function safePath(full: string): string {
  try {
    const u = new URL(full);
    return `${u.host}${u.pathname}`;
  } catch {
    return full.slice(0, 200);
  }
}
