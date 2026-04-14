<script lang="ts">
  import { page } from '$app/state';
  import type { CurrentTenant } from '$lib/types/approval';

  interface Props {
    tenant: CurrentTenant;
    forms: { code: string; name: string }[];
    open: boolean;
    onclose: () => void;
  }

  let { tenant, forms, open, onclose }: Props = $props();

  const isAdmin = $derived(tenant.role === 'owner' || tenant.role === 'admin');
  const base = $derived(`/t/${tenant.slug}`);
  const path = $derived(page.url.pathname);

  function active(href: string): boolean {
    if (href === base) return path === base;
    return path.startsWith(href);
  }

  const linkClass = (href: string) =>
    `sidebar-link block rounded px-2.5 text-[13px] ${active(href) ? 'bg-blue-50 text-blue-700 font-medium' : 'text-gray-700 hover:bg-gray-50'}`;

  // Section collapse state
  let approvalOpen = $state(true);
  let commOpen = $state(true);
  let workOpen = $state(true);
  let adminOpen = $state(true);

  let newDraftOpen = $state(false);

  function handleNav() {
    newDraftOpen = false;
    onclose();
  }
</script>

<!-- Overlay for mobile -->
{#if open}
  <button
    type="button"
    class="fixed inset-0 z-30 bg-black/30 lg:hidden"
    onclick={onclose}
    aria-label="닫기"
  ></button>
{/if}

<aside
  class="fixed top-0 left-0 z-40 h-full w-60 border-r bg-white flex flex-col transition-transform duration-200
    {open ? 'translate-x-0' : '-translate-x-full'} lg:translate-x-0 lg:static lg:z-auto"
>
  <!-- Logo -->
  <div class="flex items-center gap-2 border-b px-4 py-3">
    <a href="/" class="text-lg font-bold" onclick={handleNav}>Rigel</a>
    <span class="text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-500 truncate max-w-[120px]">
      {tenant.name}
    </span>
  </div>

  <nav class="flex-1 overflow-y-auto px-2 py-2 space-y-0.5">
    <!-- New Draft -->
    <div class="relative mb-2">
      <button
        type="button"
        class="w-full rounded bg-blue-600 px-3 py-2 text-sm text-white hover:bg-blue-700 text-left"
        onclick={(e) => { e.stopPropagation(); newDraftOpen = !newDraftOpen; }}
      >
        + 새 기안
      </button>
      {#if newDraftOpen}
        <div class="absolute left-0 top-full z-10 mt-1 w-full rounded-lg border bg-white py-1 shadow-lg">
          {#each forms as form (form.code)}
            <a
              href={`${base}/approval/drafts/new/${form.code}`}
              class="block px-3 py-2 text-sm hover:bg-gray-50"
              onclick={handleNav}
            >
              {form.name}
            </a>
          {:else}
            <p class="px-3 py-2 text-xs text-gray-500">양식 없음</p>
          {/each}
        </div>
      {/if}
    </div>

    <!-- Dashboard -->
    <a href={base} class={linkClass(base)} onclick={handleNav}>
      대시보드
    </a>

    <!-- 전자결재 Section -->
    <button
      type="button"
      class="flex w-full items-center justify-between px-3 py-0.5 text-[11px] font-semibold text-gray-400 uppercase tracking-wider mt-2"
      onclick={() => (approvalOpen = !approvalOpen)}
    >
      전자결재
      <span class="text-[10px]">{approvalOpen ? '▾' : '▸'}</span>
    </button>
    {#if approvalOpen}
      <a href={`${base}/approval/inbox`} class={linkClass(`${base}/approval/inbox`)} onclick={handleNav}>결재함</a>
      <a href={`${base}/approval/inbox?tab=drafts`} class={linkClass(`${base}/approval/inbox`)} onclick={handleNav}>내 문서</a>
    {/if}

    <!-- 소통 Section -->
    <button
      type="button"
      class="flex w-full items-center justify-between px-3 py-0.5 text-[11px] font-semibold text-gray-400 uppercase tracking-wider mt-2"
      onclick={() => (commOpen = !commOpen)}
    >
      소통
      <span class="text-[10px]">{commOpen ? '▾' : '▸'}</span>
    </button>
    {#if commOpen}
      <a href={`${base}/boards`} class={linkClass(`${base}/boards`)} onclick={handleNav}>게시판</a>
      <a href={`${base}/announcements`} class={linkClass(`${base}/announcements`)} onclick={handleNav}>공지사항</a>
    {/if}

    <!-- 업무 Section -->
    <button
      type="button"
      class="flex w-full items-center justify-between px-3 py-0.5 text-[11px] font-semibold text-gray-400 uppercase tracking-wider mt-2"
      onclick={() => (workOpen = !workOpen)}
    >
      업무
      <span class="text-[10px]">{workOpen ? '▾' : '▸'}</span>
    </button>
    {#if workOpen}
      <a href={`${base}/calendar`} class={linkClass(`${base}/calendar`)} onclick={handleNav}>일정관리</a>
      <a href={`${base}/attendance`} class={linkClass(`${base}/attendance`)} onclick={handleNav}>근태관리</a>
      <a href={`${base}/leave-calendar`} class={linkClass(`${base}/leave-calendar`)} onclick={handleNav}>휴가 캘린더</a>
    {/if}

    <!-- 관리 Section (admin only) -->
    {#if isAdmin}
      <button
        type="button"
        class="flex w-full items-center justify-between px-3 py-0.5 text-[11px] font-semibold text-gray-400 uppercase tracking-wider mt-2"
        onclick={() => (adminOpen = !adminOpen)}
      >
        관리
        <span class="text-[10px]">{adminOpen ? '▾' : '▸'}</span>
      </button>
      {#if adminOpen}
        <a href={`${base}/admin/members`} class={linkClass(`${base}/admin/members`)} onclick={handleNav}>멤버</a>
        <a href={`${base}/admin/org`} class={linkClass(`${base}/admin/org`)} onclick={handleNav}>조직 관리</a>
        <a href={`${base}/admin/forms`} class={linkClass(`${base}/admin/forms`)} onclick={handleNav}>양식</a>
        <a href={`${base}/admin/approval-rules`} class={linkClass(`${base}/admin/approval-rules`)} onclick={handleNav}>결재선 규칙</a>
        <a href={`${base}/admin/approval-templates`} class={linkClass(`${base}/admin/approval-templates`)} onclick={handleNav}>결재선 템플릿</a>
        <a href={`${base}/admin/delegations`} class={linkClass(`${base}/admin/delegations`)} onclick={handleNav}>전결 규칙</a>
        <a href={`${base}/admin/absences`} class={linkClass(`${base}/admin/absences`)} onclick={handleNav}>부재 관리</a>
        <a href={`${base}/admin/boards`} class={linkClass(`${base}/admin/boards`)} onclick={handleNav}>게시판 관리</a>
        <a href={`${base}/admin/announcements`} class={linkClass(`${base}/admin/announcements`)} onclick={handleNav}>공지 관리</a>
        <a href={`${base}/admin/rooms`} class={linkClass(`${base}/admin/rooms`)} onclick={handleNav}>회의실 관리</a>
        <a href={`${base}/admin/attendance`} class={linkClass(`${base}/admin/attendance`)} onclick={handleNav}>근태 관리</a>
        <a href={`${base}/admin/audit`} class={linkClass(`${base}/admin/audit`)} onclick={handleNav}>감사 로그</a>
      {/if}
    {/if}
  </nav>
</aside>

<style>
  :global(.sidebar-link) {
    padding-top: 2px;
    padding-bottom: 2px;
    line-height: 1.5;
  }
</style>
