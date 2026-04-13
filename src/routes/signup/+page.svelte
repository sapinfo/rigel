<script lang="ts">
  import { enhance } from '$app/forms';

  let { data, form } = $props();
  let submitting = $state(false);
</script>

<div class="mx-auto max-w-md px-6 py-16">
  <h1 class="text-2xl font-bold tracking-tight">회원가입</h1>
  <p class="mt-2 text-sm text-gray-500">Rigel 전자결재 계정 만들기</p>

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
      <span class="text-sm font-medium">이름</span>
      <input
        type="text"
        name="display_name"
        required
        autocomplete="name"
        value={form?.values?.display_name ?? ''}
        class="rounded border px-3 py-2"
        class:border-red-500={form?.errors?.fields?.display_name}
      />
      {#if form?.errors?.fields?.display_name}
        <span class="text-xs text-red-500">{form.errors.fields.display_name}</span>
      {/if}
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">이메일</span>
      <input
        type="email"
        name="email"
        required
        autocomplete="email"
        value={form?.values?.email ?? data.prefilledEmail ?? ''}
        class="rounded border px-3 py-2"
        class:border-red-500={form?.errors?.fields?.email}
      />
      {#if form?.errors?.fields?.email}
        <span class="text-xs text-red-500">{form.errors.fields.email}</span>
      {:else if data.prefilledEmail && data.redirectTo !== '/'}
        <span class="text-xs text-blue-600">초대받은 이메일로 가입하세요</span>
      {/if}
    </label>

    <label class="flex flex-col gap-1">
      <span class="text-sm font-medium">비밀번호</span>
      <input
        type="password"
        name="password"
        required
        autocomplete="new-password"
        minlength="8"
        class="rounded border px-3 py-2"
        class:border-red-500={form?.errors?.fields?.password}
      />
      {#if form?.errors?.fields?.password}
        <span class="text-xs text-red-500">{form.errors.fields.password}</span>
      {:else}
        <span class="text-xs text-gray-500">최소 8자</span>
      {/if}
    </label>

    {#if form?.errors?.form}
      <p class="text-sm text-red-600">{typeof form.errors.form === 'string' ? form.errors.form : JSON.stringify(form.errors.form)}</p>
    {:else if form?.errors}
      <p class="text-sm text-red-600">{JSON.stringify(form.errors)}</p>
    {/if}

    <button
      type="submit"
      disabled={submitting}
      class="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 disabled:opacity-50"
    >
      {submitting ? '가입 중…' : '가입'}
    </button>

    <p class="mt-4 text-center text-sm text-gray-500">
      이미 계정이 있으신가요?
      <a href="/login" class="text-blue-600 underline">로그인</a>
    </p>
  </form>
</div>
