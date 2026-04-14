<script lang="ts">
  import '../app.css';
  import { onMount } from 'svelte';
  import { installGlobalErrorHandlers } from '$lib/client/debug';

  let { children } = $props();

  onMount(() => {
    // 안정화 단계 디버그: window.onerror + unhandledrejection 전역 캐처.
    // supabase-js API 실패는 lib/client/debug.ts의 debugFetch 래퍼가 별도로 잡음.
    installGlobalErrorHandlers();
  });
</script>

<main class="min-h-screen">
  {@render children?.()}
</main>
