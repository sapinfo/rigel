<script lang="ts">
  import { enhance } from '$app/forms';

  let { form, data } = $props();
  let submitting = $state(false);
</script>

<div class="flex min-h-screen">
  <!-- 좌측: 브랜딩 (데스크탑만) -->
  <div class="hidden lg:flex lg:w-1/2 flex-col justify-center bg-gradient-to-br from-blue-600 to-indigo-700 px-12 text-white">
    <h1 class="text-4xl font-bold tracking-tight">Rigel</h1>
    <p class="mt-2 text-lg text-blue-200">올인원 그룹웨어 — 결재부터 소통까지</p>

    <div class="mt-10 grid grid-cols-2 gap-4">
      <div class="rounded-xl bg-white/10 p-4">
        <div class="text-2xl mb-2">📝</div>
        <p class="font-semibold text-sm">전자결재</p>
        <p class="text-xs text-blue-200 mt-1">전결/대결/후결/합의/병렬 — 한국형 결재 완벽 지원</p>
      </div>
      <div class="rounded-xl bg-white/10 p-4">
        <div class="text-2xl mb-2">💬</div>
        <p class="font-semibold text-sm">게시판 & 공지</p>
        <p class="text-xs text-blue-200 mt-1">부서 게시판, 필독 공지, 팝업 알림으로 소통</p>
      </div>
      <div class="rounded-xl bg-white/10 p-4">
        <div class="text-2xl mb-2">📅</div>
        <p class="font-semibold text-sm">일정 & 회의실</p>
        <p class="text-xs text-blue-200 mt-1">팀/전사 캘린더, 회의실 예약 충돌 방지</p>
      </div>
      <div class="rounded-xl bg-white/10 p-4">
        <div class="text-2xl mb-2">⏰</div>
        <p class="font-semibold text-sm">근태관리</p>
        <p class="text-xs text-blue-200 mt-1">출퇴근 기록, 지각 자동 판정, 월간 리포트</p>
      </div>
    </div>

    <div class="mt-8 flex items-center gap-4 text-xs text-blue-300">
      <span>실시간 알림</span>
      <span class="text-blue-400">·</span>
      <span>PDF & 전자서명</span>
      <span class="text-blue-400">·</span>
      <span>조직도 기반</span>
      <span class="text-blue-400">·</span>
      <span>멀티테넌트</span>
    </div>

    <p class="mt-10 text-xs text-blue-300">SMB를 위한 가벼운 올인원 그룹웨어</p>
  </div>

  <!-- 우측: 로그인 폼 -->
  <div class="flex flex-1 items-center justify-center px-6 py-16 bg-gray-50">
    <div class="w-full max-w-sm">
      <!-- 모바일에서만 보이는 로고 -->
      <div class="lg:hidden mb-8">
        <h1 class="text-2xl font-bold text-blue-600">Rigel</h1>
        <p class="text-sm text-gray-500">올인원 그룹웨어</p>
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
            class="rounded-lg border bg-white px-3 py-2.5 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
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
            class="rounded-lg border bg-white px-3 py-2.5 text-sm focus:border-blue-500 focus:ring-1 focus:ring-blue-500"
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
        © 2026 Rigel. 한국형 SMB 올인원 그룹웨어
      </p>
    </div>
  </div>
</div>
