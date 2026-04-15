<script lang="ts">
  import type { Notification, NotificationType } from '$lib/types/approval';
  import { NOTIFICATION_TYPE_LABEL } from '$lib/notificationLabels';
  import { goto } from '$app/navigation';

  type Props = {
    notifications: Notification[];
    tenantSlug: string;
    onMarkRead: (id: string) => void;
    onMarkAllRead: () => void;
    onClose: () => void;
  };

  let { notifications, tenantSlug, onMarkRead, onMarkAllRead, onClose }: Props = $props();

  const TYPE_ICON: Record<NotificationType, string> = {
    approval_requested: '📋',
    approved: '✅',
    rejected: '❌',
    commented: '💬',
    withdrawn: '↩️'
  };

  function timeAgo(dateStr: string): string {
    const diff = Date.now() - new Date(dateStr).getTime();
    const mins = Math.floor(diff / 60000);
    if (mins < 1) return '방금';
    if (mins < 60) return `${mins}분 전`;
    const hrs = Math.floor(mins / 60);
    if (hrs < 24) return `${hrs}시간 전`;
    const days = Math.floor(hrs / 24);
    return `${days}일 전`;
  }
</script>

<div class="absolute right-0 top-full z-30 mt-2 w-80 rounded-lg border bg-white shadow-xl sm:w-96">
  <div class="flex items-center justify-between border-b px-4 py-3">
    <h3 class="text-sm font-semibold">알림</h3>
    {#if notifications.some((n) => !n.read)}
      <button
        type="button"
        class="text-xs text-blue-600 hover:underline"
        onclick={() => onMarkAllRead()}
      >
        모두 읽음
      </button>
    {/if}
  </div>

  <ul class="max-h-96 overflow-y-auto">
    {#each notifications as notif (notif.id)}
      <li>
        <a
          href="/t/{tenantSlug}/approval/documents/{notif.documentId}"
          class="flex gap-3 px-4 py-3 hover:bg-gray-50"
          class:bg-blue-50={!notif.read}
          onclick={(e) => {
            // 기본 nav을 막고 markRead 먼저 실행 후 SPA goto.
            // 브라우저 즉시 nav는 진행 중인 RPC fetch를 abort 시켜 DB 업데이트를 실패시킴.
            // + full-page reload 시 layout이 remount 되며 낙관적 UI 상태가 소실됨.
            e.preventDefault();
            if (!notif.read) onMarkRead(notif.id);
            onClose();
            goto(`/t/${tenantSlug}/approval/documents/${notif.documentId}`);
          }}
        >
          <span class="text-lg">{TYPE_ICON[notif.type]}</span>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium" class:text-gray-900={!notif.read} class:text-gray-600={notif.read}>
              {notif.title}
            </p>
            {#if notif.body}
              <p class="truncate text-xs text-gray-500">{notif.body}</p>
            {/if}
            <p class="mt-0.5 text-xs text-gray-400">{timeAgo(notif.createdAt)}</p>
          </div>
          {#if !notif.read}
            <span class="mt-1 h-2 w-2 flex-shrink-0 rounded-full bg-blue-500"></span>
          {/if}
        </a>
      </li>
    {:else}
      <li class="px-4 py-8 text-center text-sm text-gray-400">
        새로운 알림이 없습니다
      </li>
    {/each}
  </ul>
</div>
