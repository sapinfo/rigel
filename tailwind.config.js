/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{html,js,svelte,ts}'],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          '-apple-system',
          'BlinkMacSystemFont',
          '"Pretendard Variable"',
          'Pretendard',
          '"Apple SD Gothic Neo"',
          '"Noto Sans KR"',
          'sans-serif'
        ]
      }
    }
  },
  plugins: []
};
