<script lang="ts">
  import { page } from '$app/state';
  import { onMount } from 'svelte';
  import { createRigelBrowserClient } from '$lib/client/supabase';
  import NotificationBell from '$lib/components/NotificationBell.svelte';
  import Sidebar from '$lib/components/Sidebar.svelte';
  import AnnouncementPopup from '$lib/components/AnnouncementPopup.svelte';
  import type { Notification } from '$lib/types/approval';

  let { data, children } = $props();

  let sidebarOpen = $state(false);
  const printMode = $derived(page.url.searchParams.get('print') === '1');

  // ─── Notifications state ──────────────────────────
  let notifications = $state<Notification[]>([]);
  let unreadCount = $state(data.unreadCount as number);

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
    const supabase = createRigelBrowserClient();

    supabase
      .rpc('get_notifications', { p_tenant_id: data.currentTenant.id })
      .then(({ data: rows }) => {
        if (rows) notifications = (rows as Record<string, unknown>[]).map(mapRow);
      });

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

{#if printMode}
  {@render children?.()}
{:else}
  <div class="flex h-screen overflow-hidden">
    <!-- Sidebar -->
    <Sidebar
      tenant={data.currentTenant}
      forms={data.forms}
      open={sidebarOpen}
      onclose={() => (sidebarOpen = false)}
    />

    <!-- Main content -->
    <div class="flex flex-1 flex-col overflow-hidden">
      <!-- Top bar (compact) -->
      <header class="flex items-center justify-between border-b bg-white px-4 py-2 lg:px-6">
        <button
          type="button"
          class="lg:hidden rounded p-1 text-gray-600 hover:text-gray-900"
          onclick={() => (sidebarOpen = true)}
          aria-label="메뉴"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>

        <div class="hidden lg:block text-sm text-gray-500">
          {data.currentTenant.name}
          <span class="text-xs px-1.5 py-0.5 rounded bg-gray-100 text-gray-500 ml-1">{data.currentTenant.role}</span>
        </div>

        <div class="flex items-center gap-3">
          <NotificationBell
            {notifications}
            {unreadCount}
            tenantSlug={data.currentTenant.slug}
            onMarkRead={markReadFn}
            onMarkAllRead={markAllReadFn}
          />
          <a
            href={`/t/${data.currentTenant.slug}/my/profile`}
            class="hidden sm:inline text-sm text-gray-600 hover:text-gray-900"
          >
            내 프로필
          </a>
          <form method="POST" action="/logout">
            <button
              type="submit"
              class="text-sm text-gray-500 hover:text-gray-800"
              aria-label="로그아웃"
            >
              로그아웃
            </button>
          </form>
        </div>
      </header>

      <!-- Page content -->
      <main class="flex-1 overflow-y-auto px-4 py-6 lg:px-8">
        <div class="mx-auto max-w-5xl">
          {@render children?.()}
        </div>
      </main>
    </div>

    <!-- Popup announcements modal -->
    {#if data.popupAnnouncements?.length > 0}
      <AnnouncementPopup
        announcements={data.popupAnnouncements}
        tenantId={data.currentTenant.id}
      />
    {/if}
  </div>
{/if}
