// src/lib/server/pdf/renderDocument.ts
// v1.2 M17: Puppeteer singleton Browser + setContent 기반 PDF 생성.
//
// 작동 원리:
//   1. 서버 boot 시 warm-up 으로 Chromium 싱글톤 launch (콜드스타트 비용 우선 부담).
//   2. PDF 요청이 들어오면 caller가 event.fetch()로 HTML을 가져와서 전달.
//      Puppeteer는 setContent()로 HTML을 로드하고 page.pdf()로 변환.
//   3. Browser disconnected 이벤트 시 싱글톤 리셋 (crash 복구, R11).
//
// 장점: self-request 쿠키 전달 문제 없음 — SvelteKit event.fetch 가 세션을 공유.
//
// 가정:
//   - adapter-node (서버 프로세스 유지). 서버리스 환경 비대응.
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
  html: string;         // 렌더링할 HTML (event.fetch로 가져온 print mode 페이지)
  baseUrl: string;      // CSS/이미지 등 상대경로 해석용 origin
}

export async function renderDocumentPdf(
  params: RenderParams
): Promise<Uint8Array> {
  const browser = await getBrowser();
  const page = await browser.newPage();

  try {
    await page.setViewport({ width: 794, height: 1123, deviceScaleFactor: 2 });

    await page.setContent(params.html, {
      waitUntil: 'networkidle0',
      timeout: 30_000
    });

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
