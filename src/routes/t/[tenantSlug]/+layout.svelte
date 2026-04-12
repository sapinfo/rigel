<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { createBrowserClient } from '@supabase/ssr';
  import { PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY } from '$env/static/public';
  import NotificationBell from '$lib/components/NotificationBell.svelte';
  import type { Notification } from '$lib/types/approval';

  let { data, children } = $props();

  let newDraftOpen = $state(false);
  let mobileNavOpen = $state(false);
  const printMode = $derived(page.url.searchParams.get('print') === '1');

  // ─── Notifications state ──────────────────────────
  let notifications = $state<Notification[]>([]);
  let unreadCount = $state(data.unreadCount as number);

  function closeDropdown() {
    newDraftOpen = false;
  }

  function closeMobileNav() {
    mobileNavOpen = false;
  }

  function mapRow(r: Record<string, unknown>): Notification {
    return {
      id: r.id as string,
      documentId: r.document_id as string,
      type: r.type as Notification['type'],
      title: r.title as string,
      body: (r.body as string | null) ?? null,
      read: r.read as boolean,
      createdAt: r.created_at as string
    };
  }

  onMount(() => {
    const supabase = createBrowserClient(PUBLIC_SUPABASE_URL, PUBLIC_SUPABASE_ANON_KEY);

    // Load initial notifications
    supabase
      .rpc('get_notifications', { p_tenant_id: data.currentTenant.id })
      .then(({ data: rows }) => {
        if (rows) notifications = (rows as Record<string, unknown>[]).map(mapRow);
      });

    // Realtime subscription
    const userId = page.data.session?.user?.id ?? '';
    const channel = supabase
      .channel(`notif:${data.currentTenant.id}`)
      .on(
        'postgres_changes',
        {
          event: 'INSERT',
          schema: 'public',
          table: 'notifications',
          filter: `user_id=eq.${userId}`
        },
        (payload: { new: Record<string, unknown> }) => {
          const notif = mapRow(payload.new);
          notif.read = false;
          notifications = [notif, ...notifications];
          unreadCount++;
        }
      )
      .subscribe();

    // Store supabase ref for mark-read actions
    markReadFn = async (id: string) => {
      const n = notifications.find((n) => n.id === id);
      if (n && !n.read) {
        n.read = true;
        unreadCount = Math.max(0, unreadCount - 1);
        await supabase.rpc('mark_notification_read', { p_notification_id: id });
      }
    };

    markAllReadFn = async () => {
      notifications.forEach((n) => (n.read = true));
      unreadCount = 0;
      await supabase.rpc('mark_all_notifications_read', {
        p_tenant_id: data.currentTenant.id
      });
    };

    return () => {
      supabase.removeChannel(channel);
    };
  });

  let markReadFn = $state<(id: string) => Promise<void>>(async () => {});
  let markAllReadFn = $state<() => Promise<void>>(async () => {});
</script>

<svelte:window onclick={closeDropdown} />

{#if !printMode}
<header class="border-b bg-white">
  <div class="mx-auto max-w-6xl px-4 py-3 sm:px-6 sm:py-4 flex items-center justify-between">
    <div class="flex items-center gap-2 sm:gap-4">
      <a href="/" class="text-lg sm:text-xl font-bold">Rigel</a>
      <span class="hidden sm:inline text-gray-300">/</span>
      <span class="hidden sm:inline text-gray-700">{data.currentTenant.name}</span>
      <span class="hidden sm:inline text-xs px-2 py-0.5 rounded bg-gray-100 text-gray-600">
        {data.currentTenant.role}
      </span>
    </div>

    <div class="flex items-center gap-2 sm:gap-4">
      <!-- Notification bell -->
      <NotificationBell
        {notifications}
        {unreadCount}
        tenantSlug={data.currentTenant.slug}
        onMarkRead={markReadFn}
        onMarkAllRead={markAllReadFn}
      />

      <!-- Desktop nav -->
      <nav class="hidden sm:flex items-center gap-4 text-sm">
        <div class="relative">
          <button
            type="button"
            class="rounded bg-blue-600 px-3 py-1.5 text-white hover:bg-blue-700"
            onclick={(e) => { e.stopPropagation(); newDraftOpen = !newDraftOpen; }}
          >
            + 새 기안
          </button>
          {#if newDraftOpen}
            <div
              class="absolute right-0 top-full z-10 mt-1 min-w-48 rounded-lg border bg-white py-1 shadow-lg"
              role="menu"
              tabindex="-1"
              onclick={(e) => e.stopPropagation()}
              onkeydown={(e) => e.key === 'Escape' && (newDraftOpen = false)}
            >
              {#each data.forms as form (form.code)}
                <a
                  href={`/t/${data.currentTenant.slug}/approval/drafts/new/${form.code}`}
                  class="block px-3 py-2 text-sm hover:bg-gray-50"
                  onclick={closeDropdown}
                >
                  {form.name}
                </a>
              {:else}
                <p class="px-3 py-2 text-xs text-gray-500">양식 없음</p>
              {/each}
            </div>
          {/if}
        </div>

        <a href={`/t/${data.currentTenant.slug}/approval/inbox`} class="hover:underline">결재함</a>
        {#if data.currentTenant.role === 'owner' || data.currentTenant.role === 'admin'}
          <a href={`/t/${data.currentTenant.slug}/admin/members`} class="hover:underline">관리</a>
        {/if}
        <form method="POST" action="/logout" class="inline">
          <button type="submit" class="text-gray-500 hover:text-gray-900">로그아웃</button>
        </form>
      </nav>

      <!-- Mobile hamburger -->
      <button
        type="button"
        class="sm:hidden rounded p-1 text-gray-600 hover:text-gray-900"
        onclick={() => (mobileNavOpen = !mobileNavOpen)}
        aria-label="메뉴"
      >
        <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
          {#if mobileNavOpen}
            <path stroke-linecap="round" stroke-linejoin="round" d="M6 18L18 6M6 6l12 12" />
          {:else}
            <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
          {/if}
        </svg>
      </button>
    </div>
  </div>

  <!-- Mobile nav panel -->
  {#if mobileNavOpen}
    <nav class="sm:hidden border-t bg-white px-4 py-3 space-y-2">
      <div class="text-xs text-gray-500">
        {data.currentTenant.name} · {data.currentTenant.role}
      </div>
      <a
        href={`/t/${data.currentTenant.slug}/approval/inbox`}
        class="block rounded px-3 py-2 text-sm hover:bg-gray-50"
        onclick={closeMobileNav}
      >
        결재함
      </a>
      {#each data.forms as form (form.code)}
        <a
          href={`/t/${data.currentTenant.slug}/approval/drafts/new/${form.code}`}
          class="block rounded px-3 py-2 text-sm hover:bg-gray-50"
          onclick={closeMobileNav}
        >
          + {form.name}
        </a>
      {/each}
      {#if data.currentTenant.role === 'owner' || data.currentTenant.role === 'admin'}
        <a
          href={`/t/${data.currentTenant.slug}/admin/members`}
          class="block rounded px-3 py-2 text-sm hover:bg-gray-50"
          onclick={closeMobileNav}
        >
          관리
        </a>
      {/if}
      <form method="POST" action="/logout">
        <button type="submit" class="block w-full rounded px-3 py-2 text-left text-sm text-gray-500 hover:bg-gray-50">
          로그아웃
        </button>
      </form>
    </nav>
  {/if}
</header>
{/if}

<div class:mx-auto={!printMode} class:max-w-6xl={!printMode} class:px-6={!printMode} class:py-8={!printMode}>
  {@render children?.()}
</div>
