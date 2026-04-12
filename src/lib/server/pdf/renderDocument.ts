// src/lib/server/pdf/renderDocument.ts
// v1.2 M17: Puppeteer singleton Browser + self-request HTML capture.
//
// 작동 원리:
//   1. 서버 boot 시 warm-up 으로 Chromium 싱글톤 launch (콜드스타트 비용 우선 부담).
//   2. PDF 요청이 들어오면 new Page → 원 요청 쿠키 전달 → /documents/[id]?print=1 로 goto
//      → page.pdf() → Buffer 응답.
//   3. Browser disconnected 이벤트 시 싱글톤 리셋 (crash 복구, R11).
//
// 가정:
//   - adapter-node (서버 프로세스 유지). 서버리스 환경 비대응.
//   - self-hosted HTTPS/HTTP — origin 을 요청 event.url.origin 으로 전달.
//   - 세션 쿠키 (@supabase/ssr) 를 그대로 전달하여 SSR load 가 동일 권한으로 실행됨.
//
// R18 배포 이미지 크기: puppeteer 번들 Chromium ~170MB. README 에 안내 필요.
// R19 Vitest/SSR 빌드 부작용: warm-up 은 hooks.server.ts 에서 SSR guard 체크 후 호출.

import puppeteer, { type Browser } from 'puppeteer';

let _browser: Browser | null = null;
let _launching: Promise<Browser> | null = null;

async function getBrowser(): Promise<Browser> {
  if (_browser && _browser.connected) return _browser;
  if (_launching) return _launching;

  _launching = puppeteer
    .launch({
      headless: true,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--font-render-hinting=none',
        '--disable-dev-shm-usage'
      ]
    })
    .then((b) => {
      _browser = b;
      b.on('disconnected', () => {
        _browser = null;
        _launching = null;
      });
      _launching = null;
      return b;
    })
    .catch((err) => {
      _launching = null;
      throw err;
    });

  return _launching;
}

/** 서버 boot 시 1회 호출 (hooks.server.ts). 실패해도 throw 하지 않음 — 첫 PDF 요청 시 재시도. */
export async function warmUpPdfRenderer(): Promise<void> {
  try {
    await getBrowser();
    console.log('[pdf] puppeteer warm-up complete');
  } catch (err) {
    console.error('[pdf] warm-up failed, will retry on first request:', err);
  }
}

export interface RenderParams {
  cookie: string;       // 원 요청의 Cookie 헤더 복사
  origin: string;       // event.url.origin
  tenantSlug: string;
  docId: string;
}

export async function renderDocumentPdf(
  params: RenderParams
): Promise<Uint8Array> {
  const browser = await getBrowser();
  const page = await browser.newPage();

  try {
    await page.setViewport({ width: 794, height: 1123, deviceScaleFactor: 2 });
    // 세션 쿠키 전달 — SSR load 가 동일 권한으로 실행됨
    if (params.cookie) {
      await page.setExtraHTTPHeaders({ cookie: params.cookie });
    }

    const url =
      `${params.origin}/t/${params.tenantSlug}` +
      `/approval/documents/${params.docId}?print=1`;

    const response = await page.goto(url, {
      waitUntil: 'networkidle0',
      timeout: 30_000
    });

    if (!response || !response.ok()) {
      throw new Error(
        `PDF render failed: HTTP ${response?.status() ?? 'n/a'} for ${url}`
      );
    }

    // 폰트 로딩 대기 (한글)
    await page.evaluate(() => document.fonts.ready);

    return await page.pdf({
      format: 'A4',
      printBackground: true,
      preferCSSPageSize: false,
      margin: {
        top: '20mm',
        right: '15mm',
        bottom: '20mm',
        left: '15mm'
      }
    });
  } finally {
    await page.close();
  }
}
