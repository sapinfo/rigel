<script lang="ts">
  import type { InboxTab, InboxCounts } from '$lib/types/approval';

  type Props = {
    active: InboxTab;
    counts: InboxCounts;
    baseHref: string;
  };

  let { active, counts, baseHref }: Props = $props();

  const tabs: { key: InboxTab; label: string }[] = [
    { key: 'pending', label: '대기' },
    { key: 'in_progress', label: '진행' },
    { key: 'completed', label: '완료' },
    { key: 'rejected', label: '반려' },
    { key: 'drafts', label: '임시저장' }
  ];
</script>

<nav class="flex gap-0 border-b">
  {#each tabs as tab (tab.key)}
    {@const isActive = active === tab.key}
    <a
      href={`${baseHref}?tab=${tab.key}`}
      class="flex items-center gap-2 border-b-2 px-4 py-2 text-sm"
      class:border-blue-600={isActive}
      class:text-blue-600={isActive}
      class:font-semibold={isActive}
      class:border-transparent={!isActive}
      class:text-gray-600={!isActive}
    >
      <span>{tab.label}</span>
      {#if counts[tab.key] > 0}
        <span
          class="rounded px-2 py-0.5 text-xs"
          class:bg-blue-100={isActive}
          class:text-blue-700={isActive}
          class:bg-gray-100={!isActive}
          class:text-gray-600={!isActive}
        >
          {counts[tab.key]}
        </span>
      {/if}
    </a>
  {/each}
</nav>
