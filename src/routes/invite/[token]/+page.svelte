<script lang="ts">
  import { enhance } from '$app/forms';
  import { page } from '$app/state';

  let { data, form } = $props();
  let submitting = $state(false);
</script>

<div class="mx-auto max-w-md px-6 py-16">
  {#if data.status === 'not_found'}
    <h1 class="text-2xl font-bold tracking-tight">초대를 찾을 수 없습니다</h1>
    <p class="mt-2 text-sm text-gray-500">
      링크가 잘못되었거나 삭제된 초대입니다. 초대해준 관리자에게 다시 요청해주세요.
    </p>
    <a href="/" class="mt-6 inline-block text-blue-600 underline">홈으로</a>

  {:else if data.status === 'expired'}
    <h1 class="text-2xl font-bold tracking-tight">만료된 초대</h1>
    <p class="mt-2 text-sm text-gray-500">
      이 초대 링크는 만료되었습니다 ({new Date(data.invitation!.expires_at).toLocaleDateString('ko-KR')})
      . 관리자에게 재발급을 요청해주세요.
    </p>

  {:else if data.status === 'already_accepted'}
    <h1 class="text-2xl font-bold tracking-tight">이미 수락한 초대</h1>
    <p class="mt-2 text-sm text-gray-500">
      이 초대는 이미 수락되었습니다. 로그인 후 {data.invitation!.tenant.name}으로 이동하세요.
    </p>
    <a href="/" class="mt-6 inline-block text-blue-600 underline">홈으로</a>

  {:else}
    {@const inv = data.invitation!}
    <h1 class="text-2xl font-bold tracking-tight">
      {inv.tenant.name}에 초대받았습니다
    </h1>
    <p class="mt-2 text-sm text-gray-500">
      역할: <strong>{inv.role}</strong>
      <br />
      초대 이메일: <strong>{inv.email}</strong>
    </p>

    {#if !data.authenticated}
      <div class="mt-8 rounded border bg-yellow-50 p-4 text-sm">
        <p class="font-medium">로그인이 필요합니다</p>
        <p class="mt-1 text-gray-600">
          초대받은 이메일(<strong>{inv.email}</strong>)로 로그인 후 이 페이지로 돌아오면 자동으로
          수락됩니다.
        </p>
        <div class="mt-4 flex gap-2">
          <a
            href={`/login?redirect=${encodeURIComponent(page.url.pathname)}`}
            class="rounded border px-3 py-2 text-center"
          >
            로그인
          </a>
          <a
            href={`/signup?redirect=${encodeURIComponent(page.url.pathname)}&email=${encodeURIComponent(inv.email)}`}
            class="rounded bg-blue-600 px-3 py-2 text-white text-center"
          >
            회원가입
          </a>
        </div>
      </div>
    {:else if data.userEmail?.toLowerCase() !== inv.email.toLowerCase()}
      <div class="mt-8 rounded border bg-red-50 p-4 text-sm">
        <p class="font-medium text-red-700">이메일 불일치</p>
        <p class="mt-1 text-gray-700">
          현재 <strong>{data.userEmail}</strong>로 로그인되어 있습니다. 초대는 <strong>{inv.email}</strong
          >으로 발급되었습니다. 로그아웃 후 초대받은 이메일로 다시 로그인해주세요.
        </p>
      </div>
    {:else}
      <form
        method="POST"
        action="?/accept"
        class="mt-8"
        use:enhance={() => {
          submitting = true;
          return async ({ update }) => {
            await update();
            submitting = false;
          };
        }}
      >
        {#if form?.error}
          <p class="mb-4 text-sm text-red-600">{form.error}</p>
        {/if}
        <button
          type="submit"
          disabled={submitting}
          class="w-full rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700 disabled:opacity-50"
        >
          {submitting ? '수락 중…' : `${inv.tenant.name}에 참여`}
        </button>
      </form>
    {/if}
  {/if}
</div>
