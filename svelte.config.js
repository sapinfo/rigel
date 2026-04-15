import adapter from '@sveltejs/adapter-node';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';

/** @type {import('@sveltejs/kit').Config} */
const config = {
  preprocess: vitePreprocess(),
  kit: {
    adapter: adapter(),
    // CSRF Origin check is enabled by default in SvelteKit 2.
    alias: {
      $lib: 'src/lib'
    },
    serviceWorker: {
      // dev에선 SW가 HMR/Vite 모듈 요청과 충돌해 "Offline" 503 폴백을 유발.
      // prod 빌드에서만 수동 등록 (+layout.svelte onMount 참조).
      register: false
    }
  },
  compilerOptions: {
    runes: true
  }
};

export default config;
