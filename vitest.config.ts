import { defineConfig } from 'vitest/config';
import path from 'node:path';

// Rigel v1.2 M16a: unit test 전용 (JCS + documentHash).
// 브라우저 환경 불필요 — crypto.subtle 은 Node 20+ global 로 사용 가능.
export default defineConfig({
  test: {
    include: ['tests/unit/**/*.test.ts'],
    environment: 'node',
    globals: false
  },
  resolve: {
    alias: {
      $lib: path.resolve(__dirname, './src/lib')
    }
  }
});
