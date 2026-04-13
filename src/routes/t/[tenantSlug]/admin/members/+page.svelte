<script lang="ts">
  import { enhance } from '$app/forms';
  import { page } from '$app/state';

  let { data, form } = $props();

  let newInviteLink = $state<string | null>(null);
  let deptFilter = $state('');

  const isOwner = $derived(data.currentTenant.role === 'owner');

  const filteredMembers = $derived(
    deptFilter ? data.members.filter((m) => m.department_id === deptFilter) : data.members
  );

  const slug = data.currentTenant.slug;
  const adminLinks = [
    ['members', '멤버'], ['org', '조직 관리'], ['forms', '양식'],
    ['approval-rules', '결재선 규칙'], ['approval-templates', '결재선 템플릿'],
    ['delegations', '전결 규칙'], ['absences', '부재 관리'], ['audit', '감사 로그']
  ];

  function fmt(iso: string): string {
    return new Date(iso).toLocaleDateString('ko-KR');
  }

  function copyLink(link: string) {
    navigator.clipboard.writeText(link);
  }
</script>

<div class="flex flex-col gap-6">
  <!-- 관리 서브네비 -->
  <nav class="flex gap-1 overflow-x-auto border-b">
    {#each adminLinks as [path, label] (path)}
      <a href="/t/{slug}/admin/{path}" class="shrink-0 px-3 py-2 text-sm" class:border-b-2={page.url.pathname.includes(`/admin/${path}`)} class:border-blue-600={page.url.pathname.includes(`/admin/${path}`)} class:text-blue-600={page.url.pathname.includes(`/admin/${path}`)} class:text-gray-500={!page.url.pathname.includes(`/admin/${path}`)}>{label}</a>
    {/each}
  </nav>

  <!-- 초대 -->
  <section class="rounded-lg border bg-white p-4">
    <h2 class="mb-3 text-base font-semibold">멤버 초대</h2>
    <form
      method="POST"
      action="?/invite"
      class="flex flex-col gap-3"
      use:enhance={() => {
        newInviteLink = null;
        return async ({ update, result }) => {
          await update({ reset: false });
          if (result.type === 'success' && result.data?.inviteLink) {
            newInviteLink = result.data.inviteLink as string;
          }
        };
      }}
    >
      <div class="flex gap-2">
        <input
          type="email"
          name="email"
          required
          placeholder="이메일"
          class="flex-1 rounded border px-3 py-2 text-sm"
        />
        <select name="role" class="rounded border px-3 py-2 text-sm">
          <option value="member">member</option>
          <option value="admin">admin</option>
        </select>
        <button
          type="submit"
          class="rounded bg-blue-600 px-4 py-2 text-sm text-white hover:bg-blue-700"
        >
          초대 생성
        </button>
      </div>
      {#if form?.errors?.form}
        <p class="text-sm text-red-600">{form.errors.form}</p>
      {/if}
      {#each Object.entries(form?.errors?.fields ?? {}) as [f, m]}
        <p class="text-xs text-red-500">{f}: {m}</p>
      {/each}
    </form>

    {#if newInviteLink}
      <div class="mt-4 rounded border border-green-300 bg-green-50 p-3 text-sm">
        <p class="mb-2 font-medium text-green-800">초대 링크 생성됨 (만료: 7일)</p>
        <div class="flex items-center gap-2">
          <input
            type="text"
            readonly
            value={newInviteLink}
            class="flex-1 rounded border bg-white px-2 py-1 text-xs"
          />
          <button
            type="button"
            onclick={() => copyLink(newInviteLink!)}
            class="rounded border px-2 py-1 text-xs hover:bg-gray-50"
          >
            복사
          </button>
        </div>
      </div>
    {/if}
  </section>

  <!-- 대기 중 초대 -->
  {#if data.invitations.filter((i) => !i.accepted_at).length > 0}
    <section>
      <h2 class="mb-2 text-base font-semibold">대기 중 초대</h2>
      <ul class="flex flex-col gap-1">
        {#each data.invitations.filter((i) => !i.accepted_at) as inv (inv.id)}
          {@const link = `${page.url.origin}/invite/${inv.token}`}
          <li class="flex items-center gap-3 rounded border bg-white px-3 py-2 text-sm">
            <span class="flex-1 truncate">{inv.email}</span>
            <span class="rounded bg-gray-100 px-2 py-0.5 text-xs">{inv.role}</span>
            <span class="text-xs text-gray-400">만료: {fmt(inv.expires_at)}</span>
            <button
              type="button"
              onclick={() => copyLink(link)}
              class="rounded border px-2 py-1 text-xs hover:bg-gray-50"
            >
              링크 복사
            </button>
            <form method="POST" action="?/cancelInvite" use:enhance>
              <input type="hidden" name="id" value={inv.id} />
              <button type="submit" class="rounded px-2 py-1 text-xs text-red-500">취소</button>
            </form>
          </li>
        {/each}
      </ul>
    </section>
  {/if}

  <!-- 멤버 목록 -->
  <section>
    <div class="mb-2 flex items-center justify-between">
      <h2 class="text-base font-semibold">멤버 ({filteredMembers.length})</h2>
      <select bind:value={deptFilter} class="rounded border px-2 py-1 text-sm">
        <option value="">전체 부서</option>
        {#each data.departments as dept (dept.id)}
          <option value={dept.id}>{dept.name}</option>
        {/each}
      </select>
    </div>
    <ul class="flex flex-col gap-1">
      {#each filteredMembers as m (m.user_id)}
        <li class="flex items-center gap-3 rounded border bg-white px-3 py-2 text-sm">
          <div class="min-w-0 flex-1">
            <div class="font-medium">{m.display_name}</div>
            <div class="text-xs text-gray-500">
              {m.email}
              {#if m.job_title}· {m.job_title}{/if}
            </div>
          </div>

          {#if isOwner && m.role !== 'owner'}
            <form method="POST" action="?/updateRole" use:enhance>
              <input type="hidden" name="user_id" value={m.user_id} />
              <select
                name="role"
                value={m.role}
                onchange={(e) => e.currentTarget.form?.requestSubmit()}
                class="rounded border px-2 py-1 text-xs"
              >
                <option value="admin">admin</option>
                <option value="member">member</option>
              </select>
            </form>
          {:else}
            <span class="rounded bg-gray-100 px-2 py-0.5 text-xs">{m.role}</span>
          {/if}

          {#if isOwner && m.role !== 'owner'}
            <form
              method="POST"
              action="?/removeMember"
              use:enhance
              onsubmit={(e) => {
                if (!confirm(`${m.display_name}을(를) 제거하시겠습니까?`)) {
                  e.preventDefault();
                }
              }}
            >
              <input type="hidden" name="user_id" value={m.user_id} />
              <button type="submit" class="rounded px-2 py-1 text-xs text-red-500">제거</button>
            </form>
          {/if}
        </li>
      {/each}
    </ul>
  </section>
</div>
