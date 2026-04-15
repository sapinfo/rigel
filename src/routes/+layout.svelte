<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { installGlobalErrorHandlers } from '$lib/client/debug';

  let { children } = $props();

  onMount(() => {
    // 안정화 단계 디버그: window.onerror + unhandledrejection 전역 캐처.
    // supabase-js API 실패는 lib/client/debug.ts의 debugFetch 래퍼가 별도로 잡음.
    installGlobalErrorHandlers();

    if (!('serviceWorker' in navigator)) return;
    if (import.meta.env.PROD) {
      // SvelteKit prod SW는 classic 스크립트로 번들됨 — type 옵션 생략 (기본값 classic).
      navigator.serviceWorker.register('/service-worker.js').catch(() => {});
    } else {
      // Dev: 이전 세션에 등록된 SW가 남아 있으면 HMR/청크 요청을 가로채 "Offline" 폴백이 뜸. 해제 후 재로드.
      navigator.serviceWorker.getRegistrations().then((regs) => {
        if (regs.length === 0) return;
        Promise.all(regs.map((r) => r.unregister())).then(() => location.reload());
      });
    }
  });
</script>

<main class="min-h-screen">
  {@render children?.()}
</main>
