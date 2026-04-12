<script lang="ts">
  import NotificationDropdown from './NotificationDropdown.svelte';
  import type { Notification } from '$lib/types/approval';

  type Props = {
    notifications: Notification[];
    unreadCount: number;
    tenantSlug: string;
    onMarkRead: (id: string) => void;
    onMarkAllRead: () => void;
  };

  let { notifications, unreadCount, tenantSlug, onMarkRead, onMarkAllRead }: Props = $props();
  let open = $state(false);

  function toggle(e: MouseEvent) {
    e.stopPropagation();
    open = !open;
  }

  function close() {
    open = false;
  }
</script>

<svelte:window onclick={close} />

<div class="relative">
  <button
    type="button"
    class="relative rounded p-1 text-gray-600 hover:text-gray-900"
    onclick={toggle}
    aria-label="알림"
  >
    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2">
      <path stroke-linecap="round" stroke-linejoin="round" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
    </svg>
    {#if unreadCount > 0}
      <span class="absolute -right-1 -top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-red-500 px-1 text-[10px] font-bold text-white">
        {unreadCount > 99 ? '99+' : unreadCount}
      </span>
    {/if}
  </button>

  {#if open}
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions -->
    <div role="dialog" tabindex="-1" onclick={(e) => e.stopPropagation()}>
      <NotificationDropdown
        {notifications}
        {tenantSlug}
        {onMarkRead}
        {onMarkAllRead}
        onClose={close}
      />
    </div>
  {/if}
</div>
