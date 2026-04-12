<script lang="ts">
  import { enhance } from '$app/forms';

  let { form, data } = $props();
  let submitting = $state(false);
</script>

<div class="flex min-h-screen">
  <!-- 좌측: 브랜딩 (데스크탑만) -->
  <div class="hidden lg:flex lg:w-1/2 flex-col justify-center bg-blue-600 px-12 text-white">
    <h1 class="text-4xl font-bold tracking-tight">Rigel</h1>
    <p class="mt-2 text-lg text-blue-200">한국형 전자결재를 쉽고 빠르게</p>

    <div class="mt-10 space-y-6">
      <div class="flex items-start gap-3">
        <div class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-blue-500 text-sm">✓</div>
        <div>
          <p class="font-semibold">결재선 자동 구성</p>
          <p class="text-sm text-blue-200">조직도 기반으로 결재선을 자동 생성하고, 즐겨찾기로 빠르게 재사용</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-blue-500 text-sm">⚡</div>
        <div>
          <p class="font-semibold">일괄 결재 & 실시간 알림</p>
          <p class="text-sm text-blue-200">여러 문서를 한 번에 승인하고, 실시간 알림으로 놓치지 않는 결재</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-blue-500 text-sm">🔒</div>
        <div>
          <p class="font-semibold">법적 효력 & 감사 추적</p>
          <p class="text-sm text-blue-200">전자서명, PDF 출력, SHA-256 해시로 문서 위변조 방지</p>
        </div>
      </div>
      <div class="flex items-start gap-3">
        <div class="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-lg bg-blue-500 text-sm">🏢</div>
        <div>
          <p class="font-semibold">한국형 결재 완벽 지원</p>
          <p class="text-sm text-blue-200">전결, 대결, 후결, 합의, 병렬결재 등 한국 기업 맞춤 워크플로우</p>
        </div>
      </div>
    </div>

    <p class="mt-12 text-xs text-blue-300">SMB를 위한 가벼운 전자결재 SaaS</p>
  </div>

  <!-- 우측: 로그인 폼 -->
  <div class="flex flex-1 items-center justify-center px-6 py-16">
    <div class="w-full max-w-sm">
      <!-- 모바일에서만 보이는 로고 -->
      <div class="lg:hidden mb-8">
        <h1 class="text-2xl font-bold text-blue-600">Rigel</h1>
        <p class="text-sm text-gray-500">한국형 전자결재를 쉽고 빠르게</p>
      </div>

      <h2 class="text-2xl font-bold tracking-tight">로그인</h2>
      <p class="mt-1 text-sm text-gray-500">업무 계정으로 로그인하세요</p>

      <form
        method="POST"
        class="mt-6 flex flex-col gap-4"
        use:enhance={() => {
          submitting = true;
          return async ({ update }) => {
            await update();
            submitting = false;
          };
        }}
      >
        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">이메일</span>
          <input
            type="email"
            name="email"
            required
            autocomplete="email"
            value={form?.values?.email ?? ''}
            placeholder="name@company.com"
            class="rounded-lg border px-3 py-2.5 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
          />
        </label>

        <label class="flex flex-col gap-1">
          <span class="text-sm font-medium">비밀번호</span>
          <input
            type="password"
            name="password"
            required
            autocomplete="current-password"
            placeholder="••••••••"
            class="rounded-lg border px-3 py-2.5 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
          />
        </label>

        {#if form?.errors?.form}
          <p class="rounded-lg bg-red-50 px-3 py-2 text-sm text-red-600">{form.errors.form}</p>
        {/if}

        <button
          type="submit"
          disabled={submitting}
          class="rounded-lg bg-blue-600 px-4 py-2.5 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {submitting ? '로그인 중…' : '로그인'}
        </button>

        {#if data.redirectTo !== '/'}
          <p class="text-xs text-gray-400 text-center">
            로그인 후 <code class="font-mono text-gray-500">{data.redirectTo}</code>로 이동
          </p>
        {/if}
      </form>

      <p class="mt-6 text-center text-sm text-gray-500">
        계정이 없으신가요?
        <a href="/signup" class="font-medium text-blue-600 hover:underline">회원가입</a>
      </p>

      <p class="mt-8 text-center text-xs text-gray-400">
        © 2026 Rigel. 한국형 SMB 전자결재 SaaS
      </p>
    </div>
  </div>
</div>
