<script lang="ts">
  import { enhance } from '$app/forms';

  let { form, data } = $props();
  let submitting = $state(false);
</script>

<div class="mx-auto max-w-md px-6 py-16">
  <h1 class="text-2xl font-bold tracking-tight">로그인</h1>
  <p class="mt-2 text-sm text-gray-500">Rigel 전자결재</p>

  <form
    method="POST"
    class="mt-8 flex flex-col gap-4"
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
        class="rounded border px-3 py-2"
      />
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">비밀번호</span>
      <input
        type="password"
        name="password"
        required
        autocomplete="current-password"
        class="rounded border px-3 py-2"
      />
    </label>

    {#if form?.errors?.form}
      <p class="text-sm text-red-600">{form.errors.form}</p>
    {/if}

    <button
      type="submit"
      disabled={submitting}
      class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 disabled:opacity-50"
    >
      {submitting ? '로그인 중…' : '로그인'}
    </button>

    {#if data.redirectTo !== '/'}
      <p class="text-xs text-gray-500 text-center">
        로그인 후 <code class="font-mono">{data.redirectTo}</code>로 이동합니다
      </p>
    {/if}

    <p class="mt-4 text-center text-sm text-gray-500">
      계정이 없으신가요?
      <a href="/signup" class="text-blue-600 underline">회원가입</a>
    </p>
  </form>
</div>
