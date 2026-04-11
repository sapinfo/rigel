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
    }
  },
  compilerOptions: {
    runes: true
  }
};

export default config;
